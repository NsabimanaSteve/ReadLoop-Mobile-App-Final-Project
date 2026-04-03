# 🖥️ ReadLoop App - Windows Terminal Commands

## 📱 **WINDOWS TERMINAL COMMANDS**

### 🚀 **FOR WEB BROWSER (Chrome/Edge):**

#### **Method 1: Separate Commands**
```cmd
cd C:\Users\user\CascadeProjects\readloop_project
flutter run -d chrome --web-port=8080
```

#### **Method 2: Single Line (Windows Compatible)**
```cmd
cd /d C:\Users\user\CascadeProjects\readloop_project && flutter run -d chrome --web-port=8080
```

#### **Method 3: PowerShell**
```powershell
Set-Location "C:\Users\user\CascadeProjects\readloop_project"
flutter run -d chrome --web-port=8080
```

### 📱 **FOR ANDROID APK BUILD:**

#### **Build Release APK**
```cmd
cd C:\Users\user\CascadeProjects\readloop_project
flutter build apk --release
```

#### **Build Debug APK**
```cmd
cd C:\Users\user\CascadeProjects\readloop_project
flutter build apk --debug
```

### 🔧 **FOR ANDROID EMULATOR:**

#### **Start Emulator**
```cmd
flutter emulators --launch <emulator_name>
```

#### **Run on Emulator**
```cmd
flutter run -d <device_id>
```

### 📋 **USEFUL FLUTTER COMMANDS:**

#### **Check Connected Devices**
```cmd
flutter devices
```

#### **Check Flutter Version**
```cmd
flutter --version
```

#### **Get Dependencies**
```cmd
flutter pub get
```

#### **Clean Build**
```cmd
flutter clean
```

### 🌐 **ACCESS YOUR APP:**

#### **Web App**
- After running, open: `http://localhost:8080` in Chrome/Edge
- Or use the URL shown in terminal output

#### **Mobile App**
- APK location: `build\app\outputs\flutter-apk\app-release.apk`
- Install on Android device or emulator

### 🔧 **TROUBLESHOOTING:**

#### **If Port is Busy:**
```cmd
flutter run -d chrome --web-port=8081
```

#### **If Build Fails:**
```cmd
flutter clean
flutter pub get
flutter run -d chrome
```

#### **Clear Flutter Cache:**
```cmd
flutter clean
```

### 📱 **QUICK START COMMANDS:**

#### **For Web Testing (Recommended):**
```cmd
cd /d C:\Users\user\CascadeProjects\readloop_project && flutter run -d chrome --web-port=8080
```

#### **For APK Building:**
```cmd
cd C:\Users\user\CascadeProjects\readloop_project && flutter build apk --release
```

#### **For Device Testing:**
```cmd
cd C:\Users\user\CascadeProjects\readloop_project && flutter devices && flutter install
```

---

## 🎯 **WINDOWS TERMINAL SPECIFIC:**

### **Why `/d` flag is needed:**
- Windows CMD doesn't support `&&` operator
- `/d` changes directory for the command duration
- Keeps the project directory as current directory

### **Alternative Approaches:**

#### **PowerShell (Recommended):**
```powershell
Set-Location "C:\Users\user\CascadeProjects\readloop_project"
flutter run -d chrome --web-port=8080
```

#### **Batch File:**
Create `run_readloop.bat`:
```batch
@echo off
cd /d C:\Users\user\CascadeProjects\readloop_project
flutter run -d chrome --web-port=8080
pause
```

## 📞 **COPY & PASTE:**

**Just copy any command above and paste it in your Windows Terminal or PowerShell!**

**Recommended command for Windows:**
```cmd
cd /d C:\Users\user\CascadeProjects\readloop_project && flutter run -d chrome --web-port=8080
```

**Happy coding with your ReadLoop app!** 🚀
