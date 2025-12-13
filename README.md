# CloudToLocalLLM

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.5%2B-blue.svg)](https://flutter.dev)
[![Node.js Version](https://img.shields.io/badge/Node.js-22%2B-green.svg)](https://nodejs.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20Web-lightgrey.svg)]()
[![Status](https://img.shields.io/badge/Status-Active%20Development-orange.svg)]()

**A privacy-first platform to manage and run powerful Large Language Models (LLMs) locally, with an optional cloud relay for seamless remote access.**

[Key Features](#key-features) • [Download & Install](#-download--install) • [Documentation](#-documentation) • [Development](#-development)

</div>

---

## 🚀 Overview

**CloudToLocalLLM** bridges the gap between secure local AI execution and the convenience of cloud-based management. Designed for privacy-conscious users and businesses, it allows you to run models like Llama 3 and Mistral entirely on your own hardware while offering an optional, secure pathway for remote interaction.

> **Note:** The project is currently in **Heavy Development/Early Access**. Premium cloud relay features are planned but not yet live.

## ✨ Key Features

*   **🔒 Privacy-First:** Run models locally using [Ollama](https://ollama.com). Your data stays on your device by default.
*   **💻 Cross-Platform:** Native support for **Windows** and **Linux**, with a responsive **Web** interface. macOS support is in progress.
*   **⚡ Hybrid Architecture:** Seamlessly switch between local models when needed.
*   **🔌 Extensible:** Integrated with LangChain for advanced AI workflows and vector store support.
*   **📊 Monitoring:** Optional Sentry integration for error tracking and performance monitoring.

## 📋 Prerequisites

To use CloudToLocalLLM locally, you only need one thing:

*   **[Ollama](https://ollama.com/download):** This is the engine that runs the AI models.
    *   After installing, pull a model to get started: `ollama pull llama3.2`

## 📥 Download & Install

### Windows & Linux
1.  Go to the **[Latest Releases](https://github.com/imrightguy/CloudToLocalLLM/releases/latest)** page.
2.  Download the installer or executable for your operating system (`.exe` for Windows, `.AppImage` or `.deb` for Linux).
3.  Run the installer and launch the application.

### Web Version
You can access the latest web deployment directly at: **[cloudtolocalllm.online](https://cloudtolocalllm.online)**

## 📖 Documentation

Comprehensive documentation is available in the `docs/` directory:

*   **[User Guide](docs/USER_DOCUMENTATION/USER_GUIDE.md):** Detailed configuration and usage instructions.
*   **:** Walkthrough for your first run.
*   **[Troubleshooting](docs/USER_DOCUMENTATION/USER_TROUBLESHOOTING_GUIDE.md):** Solutions for common issues.

## 🛠️ Development

If you are a developer looking to contribute or build from source, follow these steps.

### Tech Stack
*   **Frontend:** Flutter (Mobile, Desktop, Web)
*   **Backend:** Node.js (Express.js)
*   **AI Runtime:** Ollama / LM Studio (Local)

### Build from Source

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.5+), [Node.js](https://nodejs.org/) (22 LTS), and Git.

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/imrightguy/CloudToLocalLLM.git
    cd CloudToLocalLLM
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the App:**
    ```bash
    flutter run -d windows # or linux / chrome
    ```

For full developer details, see the **[Developer Onboarding Guide](docs/DEVELOPMENT/DEVELOPER_ONBOARDING.md)**.

## 🤝 Contributing

We welcome contributions! Please read our **[Contributing Guidelines](docs/DEVELOPMENT/CONTRIBUTING.md)** and check the [Issues](https://github.com/imrightguy/CloudToLocalLLM/issues) tab.

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

<div align="center">

**[Website](https://cloudtolocalllm.online)** • **[GitHub](https://github.com/imrightguy/CloudToLocalLLM)**

</div>
