# 🖥️ ReadLoop App - Terminal Commands

## 📱 **Flutter Run Commands for Terminal**

### **🚀 FOR WEB BROWSER (Chrome/Edge):**

#### **Method 1: Basic Web Run**
```bash
cd C:\Users\user\CascadeProjects\readloop_project
flutter run -d chrome --web-port=8080
```

#### **Method 2: Edge Browser**
```bash
cd C:\Users\user\CascadeProjects\readloop_project
flutter run -d edge --web-port=8081
```

#### **Method 3: Default Browser**
```bash
cd C:\Users\user\CascadeProjects\readloop_project
flutter run --web-port=8082
```

### **📱 FOR ANDROID APK BUILD:**

#### **Build Release APK**
```bash
cd C:\Users\user\CascadeProjects\readloop_project
flutter build apk --release
```

#### **Build Debug APK**
```bash
cd C:\Users\user\CascadeProjects\readloop_project
flutter build apk --debug
```

#### **Install APK on Connected Device**
```bash
cd C:\Users\user\CascadeProjects\readloop_project
flutter install
```

### **🔧 FOR ANDROID EMULATOR:**

#### **Start Emulator**
```bash
cd C:\Users\user\CascadeProjects\readloop_project
flutter emulators --launch <emulator_name>
```

#### **Run on Emulator**
```bash
cd C:\Users\user\CascadeProjects\readloop_project
flutter run -d <device_id>
```

### **📋 USEFUL FLUTTER COMMANDS:**

#### **Check Connected Devices**
```bash
flutter devices
```

#### **Check Flutter Version**
```bash
flutter --version
```

#### **Get Dependencies**
```bash
flutter pub get
```

#### **Clean Build**
```bash
flutter clean
```

#### **Hot Reload (while running)**
Press `r` in terminal where app is running

#### **Hot Restart (while running)**
Press `R` in terminal where app is running

#### **Quit App**
Press `q` in terminal where app is running

### **🌐 ACCESS YOUR APP:**

#### **Web App**
- After running, open: `http://localhost:8080` in Chrome/Edge
- Or use the URL shown in terminal output

#### **Mobile App**
- APK location: `build\app\outputs\flutter-apk\app-release.apk`
- Install on Android device or emulator
- Test all features on phone

### **🔧 TROUBLESHOOTING:**

#### **If Port is Busy:**
```bash
flutter run -d chrome --web-port=8083
```

#### **If Build Fails:**
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

#### **Clear Flutter Cache:**
```bash
flutter clean
```

### **📱 QUICK START COMMANDS:**

#### **For Web Testing:**
```bash
cd C:\Users\user\CascadeProjects\readloop_project && flutter run -d chrome --web-port=8080
```

#### **For APK Building:**
```bash
cd C:\Users\user\CascadeProjects\readloop_project && flutter build apk --release
```

#### **For Device Testing:**
```bash
cd C:\Users\user\CascadeProjects\readloop_project && flutter devices && flutter install
```

---

## 🎯 **RECOMMENDED COMMAND:**

**For your current setup, use this command:**

```bash
cd C:\Users\user\CascadeProjects\readloop_project && flutter run -d chrome --web-port=8080
```

**This will:**
✅ Start your ReadLoop app  
✅ Open in Chrome browser  
✅ Enable hot reload for development  
✅ Show terminal output for debugging  
✅ Use port 8080 to avoid conflicts  

## 📞 **COPY & PASTE:**

**Just copy any command above and paste it in your Terminal/CMD!**

**Happy coding with your ReadLoop app!** 🚀
