# 🚀 TechGlance - Intelligent Tech News Ecosystem

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" />
  <img src="https://img.shields.io/badge/Framework-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Language-Dart%20%7C%20Kotlin-0095D5?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/AI-Gemini%201.5%20Flash-8E75B2?style=for-the-badge&logo=google-gemini&logoColor=white" />
  <img src="https://img.shields.io/badge/Architecture-Serverless%20%2F%20Local-FF5722?style=for-the-badge&logo=firebase&logoColor=white" />
</p>

---

## 📖 Overview

**TechGlance** is a sophisticated, minimalist news aggregator and Android widget designed specifically for **Software Engineers, Data Scientists, and Tech Enthusiasts**.

Unlike standard news feeds that prioritize clickbait and general consumer electronics, TechGlance focuses on high-impact technical developments. It leverages **Google's Gemini AI** to process raw RSS feeds from top-tier engineering sources, filtering out noise and summarizing complex articles into single, technically accurate sentences.

This project demonstrates a seamless integration between a cross-platform Flutter application and native Android components (RemoteViews), operating entirely serverless with local persistence.

## ✨ Key Features

### 🧠 AI-Powered Content Processing
* **Intelligent Summarization:** Utilizes `Gemini 1.5 Flash` to condense lengthy articles into concise, engineer-to-engineer summaries.
* **Noise Filtering:** Automatically detects and discards irrelevant content (e.g., shopping deals, stock gossip, non-technical reviews).
* **Context Awareness:** Preserves critical technical terminology (LLM, Kernel, Qubit, etc.) while translating or summarizing.

### 📱 Engineering-Centric UX
* **Curated Sources:** Pre-configured with high-quality feeds like *Hacker News*, *GitHub Engineering Blog*, *arXiv (AI/CS)*, and *MIT Technology Review*.
* **Native Android Widget:** A custom-built Kotlin widget providing instant access to updates directly from the home screen without launching the app.
* **Dark Mode First:** Designed with a sleek, AMOLED-friendly UI for extended readability.

### ⚙️ Robust Architecture
* **Offline Persistence:** Implements a caching strategy using `SharedPreferences`, ensuring content availability even without an active internet connection.
* **Smart Background Refresh:** Automatically refreshes content every 12 hours to ensure relevance while respecting battery life.
* **Customizable:** Users can manage RSS sources, adjust article density, and toggle between English and Turkish languages dynamically.

---

## 🛠️ Technical Stack & Architecture

This project adopts a **Serverless / Local-First** architecture to ensure privacy and speed.

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Mobile Framework** | Flutter (Dart) | Core application logic, UI, and background fetching. |
| **Native Widget** | Kotlin | Android Home Screen widget implementation using `RemoteViews` and `AppWidgetProvider`. |
| **AI Model** | Google Gemini 1.5 | Natural Language Processing for summarization and translation. |
| **Data Source** | RSS / Atom Feeds | `webfeed` package for parsing XML data streams. |
| **Persistence** | SharedPreferences | Local key-value storage for caching news and user settings. |
| **Networking** | HTTP | Asynchronous data fetching. |

### Widget Communication Workflow
1.  **Flutter App** fetches and processes news via Gemini API.
2.  Data is serialized to JSON and stored in a shared `SharedPreferences` container.
3.  **Kotlin Native Code** (`NewsWidgetProvider`) reads directly from this shared container.
4.  The widget UI is updated via `RemoteViews` without waking up the full Flutter engine, optimizing resources.

---

## 🚀 Installation & Setup

To build and run this project locally, you need the Flutter SDK and an Android environment.

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/yorulmazkagan/TechGlance.git
    cd TechGlance/mobile
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Configuration (API Key)**
    * Get a free API Key from [Google AI Studio](https://aistudio.google.com/).
    * Run the app on an emulator or physical device.
    * Navigate to **Settings**, paste your API Key, and tap **Save & Refresh**.

4.  **Run the App**
    ```bash
    flutter run
    ```

--- 

## 🤖 AI Assistance & Development Process

This project was developed with a modern, AI-augmented workflow. 

* **Architectural Design:** The core architecture, including the Flutter-to-Native communication bridge and caching strategy, was designed by the developer.
* **Code Generation Assistance:** LLM tools were utilized to accelerate boilerplate code generation (especially for XML layouts and standard boilerplate) and to debug complex Gradle/Kotlin version compatibility issues.
* **Logic & Implementation:** All business logic, prompt engineering for the AI summarizer, and final integration were implemented and verified by the developer to ensure a robust and production-ready application.

This approach demonstrates how AI tools can be leveraged to enhance productivity while maintaining strict engineering standards and architectural integrity.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Developed with ❤️ and ☕ by <strong>yorulmazkagan</strong><br>
  <em>Computer Engineering Student @ Konya Technical University</em>
</p>