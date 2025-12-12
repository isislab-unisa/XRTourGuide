# XRTourGuide

<div align="center">

![XRTourGuide](https://img.shields.io/badge/XR-TourGuide-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![FUTURAL](https://img.shields.io/badge/EU-FUTURAL-yellow)

**Guiding Real-Life Experiences with Community-Driven XR Content**

*Enriching reality with immersive media insights using Extended Reality (XR) and Artificial Intelligence (AI) to empower rural communities.*

[Website](https://isislab-unisa.github.io/XRTourGuide/) • [FUTURAL Project](https://futural-project.eu/it/)

</div>

---

## 📖 About

**XRTourGuide** is an innovative sub-project of the EU-funded [FUTURAL initiative](https://futural-project.eu/it/), focused on creating immersive virtual tours that enrich rural communities and enhance cultural heritage preservation. By combining Extended Reality (XR) technologies with Artificial Intelligence, XRTourGuide empowers local communities to create, share, and experience interactive tours of their cultural landmarks, natural sites, and historical treasures.

### The Challenge

Many rural regions rich in cultural heritage face significant obstacles:
- **Limited Accessibility**: Cultural sites struggle to remain open due to staff shortages and deteriorating infrastructure
- **Insufficient Services**: Lack of basic visitor amenities discourages tourism
- **Low Visibility**: Weak regional branding and promotional efforts keep areas "off the map"
- **Poor Information Dissemination**: Historical and practical information about sites is fragmented and hard to find

### Our Solution

XRTourGuide provides an online platform that enables communities to create and share immersive XR virtual tours, transforming how people explore and engage with rural territories. The platform combines:
- **Web-based Authoring Tools** for easy content creation
- **Mobile Applications** for discovering and experiencing tours
- **AI-Powered Visual Recognition** to trigger contextual information
- **Community Co-Creation** through active participation of local residents and organizations

---

## ✨ Key Features

### 🎯 Extended Reality (XR)
Augment real-world views with interactive digital content, creating immersive experiences that blend physical and digital worlds.

### 🤖 AI-Powered Visual Recognition
Automatically identify objects, artwork, buildings, and natural features to trigger relevant multimedia content.

### 🎬 Multimodal Content Support
- Text descriptions
- Audio narratives
- Video presentations
- High-resolution images
- Interactive 3D models

### ☁️ Cloud-Native Architecture
Scalable, accessible Django-based web platform built for reliability and performance.

### 🎮 Gamification Elements
Engage users through interactive challenges, achievements, and social sharing features.

### 🌍 Multi-Language Support
Make cultural content accessible to international audiences with comprehensive language support.

---

## 🏛️ Use Cases

XRTourGuide is being piloted in the **Bussento, Lambro, and Mingardo** rural communities:

### **Nilus Trail**
Highlighting the historical route of Saint Nilus, showcasing art, nature, and faith landmarks in the Byzantine Cilento (UNESCO World Heritage Site).

### **Morigerati Heritage**
Featuring the Ethnographic Museum's collection, emphasizing local traditions and targeting diverse audiences.

### **MushroomMate**
Identifying local mushroom species and sharing traditional recipes, promoting food culture and knowledge transfer.

---

## 🏗️ Project Structure

```
XRTourGuide/
├── AI_classification/       # AI models for visual recognition and image classification
├── community_server/        # Backend server for community features
├── mobile/                  # Mobile application (multi-platform)
├── pmtiles-server/         # Map tiles server for geographic data
├── xr_tour_guide/          # Core XR tour guide platform (Django)
├── LICENSE                  # MIT License
└── README.md               # Project documentation
```

---

## 🚀 Getting Started

### Prerequisites
- Docker and Docker Compose
- Git

### Quick Start

1. **Clone the repository**
```bash
git clone https://github.com/isislab-unisa/XRTourGuide.git
cd XRTourGuide
```

2. **Start all services**
```bash
docker compose up -d --build
```

That's it! The platform will be available at the configured ports.

### Development Setup

For local development without Docker:

**Web Platform (Django)**
```bash
cd xr_tour_guide
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

**Mobile App**
```bash
cd mobile
flutter pub get
flutter run
```

**AI Classification**
```bash
cd AI_classification
pip install -r requirements.txt
# Refer to AI_classification/README.md for specific instructions
```

---

## 🤝 Contributing

We welcome contributions from the community! Whether you're fixing bugs, adding features, or improving documentation, your help is appreciated.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please read our [Contributing Guidelines](CONTRIBUTING.md) for more details.

---

## 🌟 Impact & Goals

### Expected Outcomes
- **Boost Tourism**: Increase year-round visitor flow with engaging, immersive tours
- **Community Engagement**: Raise cultural awareness and encourage citizen participation
- **Economic Growth**: Generate local job opportunities in content creation and tourism
- **Sustainability**: Support sustainable tourism and preserve cultural/natural heritage

---

## 👥 Partners

XRTourGuide is a collaborative effort bringing together:

- **[Università degli Studi di Salerno (UNISA)](https://www.unisa.it/)**
- **[ISISLab](https://www.isislab.it)** - Expertise in Cloud/Edge Computing, AI, VR, and project        coordination
- **[Picaresque S.R.L.](https://tech.picaresquestudio.com/)** - Specialists in historical/serious games and software development
- **[Comunità Montana Bussento Lambro e Mingardo (CMBLM)](https://www.cmbussento.it/)** - Pilot rural community partner

### Part of FUTURAL

XRTourGuide is a sub-project of [FUTURAL](https://futural-project.eu/it/) - an EU-funded initiative producing innovative, community-driven solutions to address key social, environmental, and financial challenges in rural areas across Europe.

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Contact & Resources

- **Project Website**: [isislab-unisa.github.io/XRTourGuide](https://isislab-unisa.github.io/XRTourGuide/)
- **FUTURAL Project**: [futural-project.eu](https://futural-project.eu/it/)
- **Research Group**: [ISISLab - UNISA](https://www.isislab.it/)
- **GitHub Issues**: [Report bugs or request features](https://github.com/isislab-unisa/XRTourGuide/issues)

---

## 🏆 Acknowledgments

<div align="center">

**Co-funded by the European Union**

*The views and opinions expressed are those of the author(s) only and do not necessarily reflect those of the European Union or European Research Executive Agency. Neither the European Union nor the granting authority can be held responsible for them.*

---

**Made with ❤️ for rural communities**

*Empowering the future of rural areas through innovative technology*

</div>