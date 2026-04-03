<?php
// Database configuration
class Config {
    // Local development settings
    const DB_HOST = 'localhost';
    const DB_USER = 'root';
    const DB_PASS = '';
    const DB_NAME = 'readloop_db';
    
    // API settings
    const API_VERSION = '1.0.0';
    const ALLOWED_ORIGINS = '*';
    
    // Security settings
    const JWT_SECRET = 'your-secret-key-here';
    const PASSWORD_MIN_LENGTH = 6;
    
    // App settings
    const MAX_FILE_SIZE = 5242880; // 5MB
    const ALLOWED_IMAGE_TYPES = ['jpg', 'jpeg', 'png', 'gif'];
}
?>
