# 🌐 ReadLoop Live Server Deployment Guide

## 🎯 **YOUR SERVER DETAILS:**
- **Server**: 169.239.251.102
- **Username**: steve.nsabimana
- **Web Port**: 280
- **phpMyAdmin**: http://169.239.251.102:280/phpmyadmin
- **Upload URL**: http://169.239.251.102:280/~steve.nsabimana/upload.php
- **FTP**: Port 221, Path: /public_html

## 📋 **DEPLOYMENT STEPS:**

### **Step 1: Database Setup**
1. **Open phpMyAdmin**: http://169.239.251.102:280/phpmyadmin
2. **Login** with your MySQL credentials
3. **Create Database**: `readloop_db`
4. **Run SQL**: Copy contents of `database_setup.sql` and run in SQL tab

### **Step 2: Upload API Files**
1. **Go to Upload URL**: http://169.239.251.102:280/~steve.nsabimana/upload.php
2. **Upload**: `api_server.php` file
3. **Rename**: Uploaded file to `api/index.php`

### **Step 3: Configure API**
1. **Edit** `api/index.php` on server
2. **Update**: Change `YOUR_MYSQL_PASSWORD` to your actual MySQL password
3. **Save** the file

### **Step 4: Update Flutter App**
1. **Update main.dart** to use `readloop_live_server.dart`
2. **Build web app**: `flutter build web --release`
3. **Upload** build/web folder to server

### **Step 5: Test Connection**
1. **Open app**: http://169.239.251.102:280/~steve.nsabimana
2. **Test registration**: Create new account
3. **Verify server data**: Check if saved in database

## 🔧 **FILES TO UPLOAD:**

### **Backend Files:**
- ✅ `api_server.php` → `api/index.php`
- ✅ `database_setup.sql` → Run in phpMyAdmin

### **Frontend Files:**
- ✅ `build/web/` → Upload to server root
- ✅ Update `main.dart` to use live server version

## 🎯 **LIVE URL:**
**Your app will be available at**: http://169.239.251.102:280/~steve.nsabimana

## ✅ **VERIFICATION:**

### **Test Registration:**
1. **Sign up** with new account
2. **Check phpMyAdmin** → users table
3. **Confirm** data is saved

### **Test Login:**
1. **Login** with registered account
2. **Verify** successful authentication
3. **Check** server connection status

### **Test Data Persistence:**
1. **Click menu** → "Verify Server Data"
2. **Confirm** data exists on server
3. **Check** connection status indicator

## 🎉 **SUCCESS INDICATORS:**

### **✅ Working Setup:**
- **Green cloud icon** in app header
- **No server connection warnings**
- **Data saves to database**
- **Registration/Login works**

### **❌ Issues:**
- **Orange cloud icon** → Server connection issue
- **Offline mode warnings** → Check API files
- **Database errors** → Check MySQL setup

## 🚀 **TROUBLESHOOTING:**

### **If API doesn't work:**
1. **Check file permissions** on server
2. **Verify MySQL password** in api/index.php
3. **Test API endpoints** directly in browser
4. **Check PHP error logs**

### **If database fails:**
1. **Verify database name**: `readloop_db`
2. **Check table creation**: Run SQL again
3. **Confirm user permissions**: MySQL user access

### **If app doesn't load:**
1. **Check build files**: All files uploaded
2. **Verify file paths**: Correct directory structure
3. **Clear browser cache**: Hard refresh

## 🌐 **GOING LIVE:**

### **Once everything works:**
1. **Buy domain** (optional)
2. **Point domain** to server IP
3. **Update API URL** in Flutter code
4. **Deploy to root** directory
5. **Setup SSL certificate** (HTTPS)

## 🎯 **FINAL URL:**
**Your ReadLoop app will be live at**: http://169.239.251.102:280/~steve.nsabimana

**All user data will be saved to your live MySQL database!** 🎉
