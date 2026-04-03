# 🚀 ReadLoop Backend Setup Guide

## ✅ **Backend System Ready!**

Your ReadLoop app needs a complete backend to work properly. Here's how to set it up:

## 📋 **What You Need:**

### **1. Local Server (XAMPP/MAMP)**
- **XAMPP**: https://www.apachefriends.org/
- **MAMP**: https://www.mamp.info/
- **WAMP**: https://www.wampserver.com/

### **2. Database Setup**
- MySQL database
- PHP API files
- Configuration setup

## 🔧 **Step-by-Step Setup:**

### **Step 1: Install Local Server**
1. **Download XAMPP** from apachefriends.org
2. **Install XAMPP** (follow installer)
3. **Start Apache + MySQL** from XAMPP Control Panel
4. **Verify server** at http://localhost/

### **Step 2: Create Database**
1. **Open phpMyAdmin** at http://localhost/phpmyadmin
2. **Create new database**: `readloop_db`
3. **Import this SQL**:

```sql
CREATE TABLE users (
    id VARCHAR(255) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255),
    password VARCHAR(255),
    avatar_url VARCHAR(500),
    bio TEXT,
    favorite_genres JSON,
    daily_reading_goal INT DEFAULT 30,
    weekly_reading_goal INT DEFAULT 210,
    current_streak INT DEFAULT 0,
    longest_streak INT DEFAULT 0,
    books_read INT DEFAULT 0,
    pages_read INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_active TIMESTAMP NULL
);

CREATE TABLE books (
    id VARCHAR(255) PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    author VARCHAR(255) NOT NULL,
    isbn VARCHAR(20),
    description TEXT,
    cover_url VARCHAR(500),
    page_count INT,
    genre VARCHAR(100),
    published_date DATE,
    user_id VARCHAR(255),
    status ENUM('want_to_read', 'currently_reading', 'finished') DEFAULT 'want_to_read',
    rating DECIMAL(2,1),
    current_page INT DEFAULT 0,
    notes TEXT,
    reading_lists JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE reading_circles (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    creator_id VARCHAR(255),
    book_id VARCHAR(255),
    book_title VARCHAR(500),
    book_cover_url VARCHAR(500),
    genre VARCHAR(100),
    member_ids JSON,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    location_name VARCHAR(255),
    is_public BOOLEAN DEFAULT TRUE,
    max_members INT DEFAULT 50,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP NULL,
    FOREIGN KEY (creator_id) REFERENCES users(id)
);
```

### **Step 3: Place PHP Files**
Copy these files to `C:/xampp/htdocs/readloop/`:

1. **api/index.php** - Main API file
2. **api/config.php** - Database configuration
3. **api/.htaccess** - URL rewriting

## 📁 **PHP Files Ready:**

I've already created all the PHP files you need:

✅ **api/index.php** - Complete REST API
✅ **api_local_server.php** - Local testing API
✅ **test_db.php** - Database connection test

## 🌐 **Test Local Backend:**

### **1. Start XAMPP**
- Open XAMPP Control Panel
- Start Apache
- Start MySQL

### **2. Test API**
Open in browser: http://localhost/readloop/api/

Should see:
```json
{
  "status": "Local API Server Running",
  "database": "readloop_db",
  "endpoints": ["users", "books", "circles"]
}
```

### **3. Test Endpoints**
- **Users**: http://localhost/readloop/api/?action=users
- **Books**: http://localhost/readloop/api/?action=books
- **Circles**: http://localhost/readloop/api/?action=circles

## 🔗 **Connect Flutter to Local Backend:**

### **Update Flutter App:**
1. **Open**: `lib/services/api_service.dart`
2. **Change URL** from your live server to:
   ```dart
   static const String _baseUrl = 'http://localhost/readloop/api';
   ```
3. **Re-run Flutter app**

### **Test Integration:**
1. **Run local API server**
2. **Run Flutter app**
3. **Test all features** - Users, Books, Circles

## 🎯 **Complete System:**

```
📱 Flutter App (localhost:8093)
    ↓ (HTTP Requests)
🌐 Local PHP API (localhost/readloop/api)
    ↓ (MySQL Queries)
🗄️ Local MySQL Database (readloop_db)
```

## 🚀 **Ready for Production:**

Once local testing works:

1. **Upload API** to your live server
2. **Change Flutter URL** to your server
3. **Build new APK** with live backend
4. **Deploy complete system**

## 📞 **Need Help?**

### **Common Issues:**
- **Apache won't start**: Port 80 busy, change to 8080
- **MySQL won't start**: Port 3306 busy, stop other services
- **API not found**: Check file paths in htdocs
- **Database errors**: Verify MySQL credentials

### **Quick Tests:**
```bash
# Test PHP
php -S localhost:8000 api/index.php

# Test MySQL
mysql -u root -p

# Check Apache logs
C:/xampp/apache/logs/error.log
```

## 🎉 **Your Complete System:**

✅ **Frontend**: Beautiful Flutter app  
✅ **Backend**: Professional PHP API  
✅ **Database**: Structured MySQL  
✅ **Local Testing**: Full development environment  
✅ **Production Ready**: Deploy to live server  

**You now have a complete full-stack system!** 🚀
