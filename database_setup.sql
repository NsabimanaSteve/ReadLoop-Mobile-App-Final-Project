-- ReadLoop Database Setup
-- Run this in your phpMyAdmin SQL tab

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS readloop_db;

-- Use the database
USE readloop_db;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    displayName VARCHAR(255) NOT NULL,
    currentStreak INT DEFAULT 0,
    booksRead INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create books table
CREATE TABLE IF NOT EXISTS books (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255) NOT NULL,
    status ENUM('want_to_read', 'currently_reading', 'finished') DEFAULT 'want_to_read',
    totalPages INT DEFAULT 200,
    currentPage INT DEFAULT 0,
    userId INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
);

-- Create reading_circles table
CREATE TABLE IF NOT EXISTS reading_circles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    isPublic BOOLEAN DEFAULT TRUE,
    createdBy INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (createdBy) REFERENCES users(id) ON DELETE CASCADE
);

-- Create circle_members table
CREATE TABLE IF NOT EXISTS circle_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    circleId INT,
    userId INT,
    joinedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (circleId) REFERENCES reading_circles(id) ON DELETE CASCADE,
    FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_circle_user (circleId, userId)
);

-- Insert sample data (optional)
INSERT INTO users (email, password, displayName, currentStreak, booksRead) VALUES 
('demo@readloop.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Demo User', 5, 12);

INSERT INTO books (title, author, status, totalPages, currentPage, userId) VALUES 
('The Great Gatsby', 'F. Scott Fitzgerald', 'currently_reading', 200, 90, 1),
('To Kill a Mockingbird', 'Harper Lee', 'finished', 324, 324, 1),
('1984', 'George Orwell', 'want_to_read', 328, 0, 1);

INSERT INTO reading_circles (name, description, isPublic, createdBy) VALUES 
('Flutter Developers', 'Learning Flutter together', TRUE, 1),
('Classic Literature', 'Exploring classic novels', TRUE, 1);

-- Success message
SELECT 'ReadLoop Database Setup Complete!' as message;
