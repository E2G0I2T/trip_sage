const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const itinerarySchema = {
  type: "object",
  properties: {
    days: {
      type: "array",
      items: {
        type: "object",
        properties: {
          dayIndex: { type: "integer", description: "1부터 시작하는 일차" },
          date: { type: "string", description: "YYYY-MM-DD 형식" },
          places: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string", description: "장소 이름" },
                category: {
                  type: "string",
                  enum: ["식사", "관광", "액티비티", "숙소", "이동"]
                },
                startTime: { type: "string", description: "HH:MM 형식" },
                durationMinutes: { type: "integer" },
                estimatedCost: { type: "integer", description: "1인당 예상 비용, 원화" },
                memo: { type: "string", description: "한 줄 팁이나 설명" }
              },
              required: ["name", "category", "startTime", "durationMinutes", "estimatedCost"]
            }
          }
        },
        required: ["dayIndex", "date", "places"]
      }
    }
  },
  required: ["days"]
};

exports.generateItinerary = onCall(
  { secrets: [geminiApiKey], region: "asia-northeast3" },
  async (request) => {
    const { destination, startDate, endDate, budget, travelStyle } = request.data;

    if (!destination || !startDate || !endDate || !budget) {
      throw new HttpsError("invalid-argument", "destination, startDate, endDate, budget는 필수예요.");
    }

    const start = new Date(startDate);
    const end = new Date(endDate);
    const dayCount = Math.round((end - start) / (1000 * 60 * 60 * 24)) + 1;

    if (!Number.isFinite(dayCount) || dayCount < 1 || dayCount > 14) {
      throw new HttpsError("invalid-argument", "여행 기간은 1일에서 14일 사이여야 해요.");
    }

    const apiKeyValue = geminiApiKey.value();
    if (!apiKeyValue) {
      throw new HttpsError("internal", "GEMINI_API_KEY 시크릿 값이 비어있어요.");
    }

    process.env.GEMINI_API_KEY = apiKeyValue;
    const { GoogleGenAI } = await import("@google/genai");
    const ai = new GoogleGenAI({ apiKey: apiKeyValue });

    const prompt = `
당신은 전문 여행 플래너입니다. 아래 조건에 맞는 일정을 짜주세요.

목적지: ${destination}
여행 기간: ${startDate}부터 ${endDate}까지 (총 ${dayCount}일)
총 예산: ${budget}원
여행 스타일: ${travelStyle || "균형 잡힌 일반 여행"}

각 날짜별로 시간대 순서대로 장소를 배치하고, 식사 시간도 포함해주세요.
date 필드는 ${startDate}부터 시작해서 하루씩 늘려가며 실제 날짜로 정확히 채워주세요.
예상 비용은 현실적인 1인 기준 금액으로 추정해주세요.
`;

    let response;
    try {
      response = await ai.models.generateContent({
        model: "gemini-2.5-flash",
        contents: prompt,
        config: {
          responseMimeType: "application/json",
          responseJsonSchema: itinerarySchema
        }
      });
    } catch (error) {
      console.error("Gemini API 호출 실패:", error);
      throw new HttpsError("internal", "AI 일정 생성에 실패했어요: " + error.message);
    }

    try {
      return JSON.parse(response.text);
    } catch (error) {
      console.error("JSON 파싱 실패:", response.text);
      throw new HttpsError("internal", "AI 응답을 파싱하는 데 실패했어요.");
    }
  }
);