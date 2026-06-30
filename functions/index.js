const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const mapsApiKey = defineSecret("MAPS_API_KEY");

const itinerarySchema = {
  type: "object",
  properties: {
    days: {
      type: "array",
      items: {
        type: "object",
        properties: {
          dayIndex: { type: "integer" },
          date: { type: "string" },
          places: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" }, // 순수 장소명만 (예: "센소지", "이치란 라멘 신주쿠점")
                activity: { type: "string" }, // 해당 장소에서 하는 활동 (예: "관광 및 산책", "점심 식사")
                category: {
                  type: "string",
                  enum: ["식사", "관광", "액티비티", "숙소", "이동"],
                },
                startTime: { type: "string" },
                durationMinutes: { type: "integer" },
                estimatedCost: { type: "integer" },
                memo: { type: "string" },
              },
              required: [
                "name",
                "activity",
                "category",
                "startTime",
                "durationMinutes",
                "estimatedCost",
              ],
            },
          },
        },
        required: ["dayIndex", "date", "places"],
      },
    },
  },
  required: ["days"],
};

async function generateWithRetry(ai, params, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await ai.models.generateContent(params);
    } catch (error) {
      const isRetryable =
        error.message?.includes("UNAVAILABLE") ||
        error.message?.includes("503") ||
        error.message?.includes("overloaded");
      if (!isRetryable || attempt === maxRetries) throw error;
      const delayMs = attempt * 1500;
      console.log(
        `Gemini 일시적 오류, ${delayMs}ms 후 재시도 (${attempt}/${maxRetries})`,
      );
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
}

exports.generateItinerary = onCall(
  { secrets: [geminiApiKey], region: "asia-northeast3" },
  async (request) => {
    const {
      destination,
      origin,
      startDate,
      endDate,
      budget,
      travelStyle,
      transportMode,
    } = request.data;

    if (!destination || !startDate || !endDate || !budget) {
      throw new HttpsError(
        "invalid-argument",
        "destination, startDate, endDate, budget는 필수예요.",
      );
    }

    const start = new Date(startDate);
    const end = new Date(endDate);
    const dayCount = Math.round((end - start) / (1000 * 60 * 60 * 24)) + 1;

    if (!Number.isFinite(dayCount) || dayCount < 1 || dayCount > 14) {
      throw new HttpsError(
        "invalid-argument",
        "여행 기간은 1일에서 14일 사이여야 해요.",
      );
    }

    const apiKeyValue = geminiApiKey.value();
    if (!apiKeyValue)
      throw new HttpsError("internal", "GEMINI_API_KEY가 없어요.");

    process.env.GEMINI_API_KEY = apiKeyValue;
    const { GoogleGenAI } = await import("@google/genai");
    const ai = new GoogleGenAI({ apiKey: apiKeyValue });

    const originLine = origin ? `출발지: ${origin}` : "";
    const prompt = `
당신은 전문 여행 플래너입니다. 아래 조건에 맞는 일정을 짜주세요.

${originLine}
목적지: ${destination}
여행 기간: ${startDate}부터 ${endDate}까지 (총 ${dayCount}일)
총 예산: ${budget}원
여행 스타일: ${travelStyle || "균형 잡힌 일반 여행"}
이동 수단: ${transportMode || "대중교통"}

${origin ? `출발지(${origin})에서 목적지(${destination})까지의 이동 일정도 첫날에 포함해주세요.` : ""}
이동 수단(${transportMode || "대중교통"})에 맞는 동선과 이동 방법을 고려해서 일정을 짜주세요.
각 날짜별로 시간대 순서대로 장소를 배치하고, 식사 시간도 포함해주세요.
date 필드는 ${startDate}부터 시작해서 하루씩 늘려가며 실제 날짜로 정확히 채워주세요.
예상 비용은 현실적인 1인 기준 금액으로 추정해주세요.

[장소명 규칙 - 반드시 준수]
- name 필드: 실제 존재하는 구체적인 장소명만 입력 (예: "센소지", "이치란 라멘 신주쿠점", "나리타국제공항", "신주쿠 프린스 호텔")
- name 필드: "신주쿠 호텔", "현지 맛집", "숙소" 같은 모호한 이름 절대 사용 금지
- activity 필드: 해당 장소에서 하는 활동 입력 (예: "체크인", "점심 식사", "관광 및 산책")
- 이동 카테고리의 name: 출발지 장소명만 입력 (예: "신주쿠역"), activity에 목적지 포함 (예: "나리타공항으로 이동")
`;

    // 이하 기존 코드 동일 (generateWithRetry, return JSON.parse 부분)
    let response;
    try {
      response = await generateWithRetry(ai, {
        model: "gemini-2.5-flash",
        contents: prompt,
        config: {
          responseMimeType: "application/json",
          responseJsonSchema: itinerarySchema,
        },
      });
    } catch (error) {
      console.error("Gemini API 호출 실패:", error);
      throw new HttpsError(
        "internal",
        "AI 일정 생성에 실패했어요: " + error.message,
      );
    }

    try {
      return JSON.parse(response.text);
    } catch (error) {
      throw new HttpsError("internal", "AI 응답 파싱 실패");
    }
  },
);

exports.editItinerary = onCall(
  { secrets: [geminiApiKey], region: "asia-northeast3" },
  async (request) => {
    const { currentItineraryJson, userMessage, destination } = request.data;

    if (!currentItineraryJson || !userMessage || !destination) {
      throw new HttpsError(
        "invalid-argument",
        "currentItineraryJson, userMessage, destination은 필수예요.",
      );
    }

    let currentItinerary;
    try {
      currentItinerary = JSON.parse(currentItineraryJson);
    } catch (e) {
      throw new HttpsError(
        "invalid-argument",
        "currentItineraryJson 파싱 실패: " + e.message,
      );
    }

    const apiKeyValue = geminiApiKey.value();
    if (!apiKeyValue)
      throw new HttpsError("internal", "GEMINI_API_KEY가 없어요.");

    process.env.GEMINI_API_KEY = apiKeyValue;
    const { GoogleGenAI } = await import("@google/genai");
    const ai = new GoogleGenAI({ apiKey: apiKeyValue });

    const prompt = `
당신은 전문 여행 플래너입니다. 아래는 ${destination} 여행 일정입니다.

현재 일정:
${JSON.stringify(currentItinerary, null, 2)}

사용자 요청: "${userMessage}"

위 요청을 반영해서 일정을 수정해주세요.
- 요청한 부분만 최소한으로 변경하고 나머지는 그대로 유지해주세요.
- date, dayIndex 값은 절대 변경하지 마세요.
- 수정된 전체 일정을 JSON으로 반환해주세요.

[장소명 규칙 - 반드시 준수]
- name 필드: 실제 존재하는 구체적인 장소명만 입력 (예: "센소지", "이치란 라멘 신주쿠점", "나리타국제공항")
- name 필드: "신주쿠 호텔", "현지 맛집", "숙소" 같은 모호한 이름 절대 사용 금지
- activity 필드: 해당 장소에서 하는 활동 입력 (예: "체크인", "점심 식사", "관광 및 산책")
- 이동 카테고리의 name: 출발지 장소명만 입력, activity에 목적지 포함 (예: "나리타공항으로 이동")
`;

    let response;
    try {
      response = await generateWithRetry(ai, {
        model: "gemini-2.5-flash",
        contents: prompt,
        config: {
          responseMimeType: "application/json",
          responseJsonSchema: itinerarySchema,
        },
      });
    } catch (error) {
      console.error("Gemini editItinerary 실패:", error);
      throw new HttpsError(
        "internal",
        "일정 수정에 실패했어요: " + error.message,
      );
    }

    try {
      return JSON.parse(response.text);
    } catch (error) {
      throw new HttpsError("internal", "AI 응답 파싱 실패");
    }
  },
);

exports.geocodePlaces = onCall(
  { secrets: [mapsApiKey], region: "asia-northeast3" },
  async (request) => {
    const { queries } = request.data;
    if (!Array.isArray(queries) || queries.length === 0) {
      throw new HttpsError("invalid-argument", "queries 배열이 필요해요.");
    }

    const apiKeyValue = mapsApiKey.value();
    if (!apiKeyValue)
      throw new HttpsError("internal", "MAPS_API_KEY가 없어요.");

    const results = await Promise.all(
      queries.map(async (query) => {
        try {
          const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(query)}&key=${apiKeyValue}`;
          const res = await fetch(url);
          const data = await res.json();
          console.log(`지오코딩 [${query}]: status=${data.status}`);
          if (data.status !== "OK" || !data.results.length) return null;
          const location = data.results[0].geometry.location;
          return { lat: location.lat, lng: location.lng };
        } catch (e) {
          console.error(`지오코딩 에러 [${query}]:`, e);
          return null;
        }
      }),
    );

    return { results };
  },
);
