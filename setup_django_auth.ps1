# Django Basic Auth Setup Script - Auto-start version
# Run this in PowerShell: .\setup_django_auth.ps1

param(
    [string]$ProjectName = "myProject",
    [string]$AppName = "accounts",
    [string]$Port = "8000"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Django Basic Auth Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Python is installed
try {
    $pythonVersion = python --version 2>$null
    if (-not $pythonVersion) {
        Write-Host "ERROR: Python is not installed or not in PATH" -ForegroundColor Red
        exit 1
    }
    Write-Host "Found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Create project directory
$projectPath = Join-Path $PWD $ProjectName
if (Test-Path $projectPath) {
    Write-Host "ERROR: Directory '$ProjectName' already exists" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $projectPath | Out-Null
Set-Location $projectPath
Write-Host "Created project directory: $projectPath" -ForegroundColor Green

# Create virtual environment
Write-Host "`n[1/8] Creating virtual environment..." -ForegroundColor Yellow
python -m venv env
Write-Host "Virtual environment created" -ForegroundColor Green

# Activate virtual environment
$envPath = Join-Path $projectPath "env\Scripts\Activate.ps1"
& $envPath

# Create requirements.txt
Write-Host "`n[2/8] Creating requirements.txt..." -ForegroundColor Yellow
$requirements = @"
django>=4.2.0
djangorestframework>=3.14.0
"@
Set-Content -Path "requirements.txt" -Value $requirements

# Install dependencies
Write-Host "`n[3/8] Installing dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt

# Create Django project
Write-Host "`n[4/8] Creating Django project..." -ForegroundColor Yellow
django-admin startproject $ProjectName .

# Create Django app
Write-Host "`n[5/8] Creating Django app..." -ForegroundColor Yellow
python manage.py startapp $AppName

# ==================== CREATE SETTINGS.PY ====================
Write-Host "`n[6/8] Configuring settings..." -ForegroundColor Yellow

$settingsPath = Join-Path $projectPath "$ProjectName\settings.py"
$settingsContent = @"
from pathlib import Path
import os

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = 'django-insecure-your-secret-key-here-change-in-production'

DEBUG = True

ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    '$AppName',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = '$ProjectName.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = '$ProjectName.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATICFILES_DIRS = [BASE_DIR / 'static']

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Django REST Framework settings
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.BasicAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

LOGIN_URL = '/login/'
LOGIN_REDIRECT_URL = '/dashboard/'
LOGOUT_REDIRECT_URL = '/'
"@

Set-Content -Path $settingsPath -Value $settingsContent

# ==================== CREATE URLS.PY (Project Level) ====================
Write-Host "Configuring URLs..." -ForegroundColor Yellow

$projectUrlsPath = Join-Path $projectPath "$ProjectName\urls.py"
$projectUrlsContent = @"
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('${AppName}.urls')),
]
"@

Set-Content -Path $projectUrlsPath -Value $projectUrlsContent

# ==================== CREATE APP FILES ====================
Write-Host "`n[7/8] Creating authentication views and templates..." -ForegroundColor Yellow

# Create directories
New-Item -ItemType Directory -Path "templates" -Force | Out-Null
New-Item -ItemType Directory -Path "templates\$AppName" -Force | Out-Null
New-Item -ItemType Directory -Path "static\css" -Force | Out-Null

# Create app urls.py
$appUrlsPath = Join-Path $projectPath "$AppName\urls.py"
$appUrlsContent = @"
from django.urls import path
from . import views

urlpatterns = [
    path('', views.home, name='home'),
    path('signup/', views.signup, name='signup'),
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('dashboard/', views.dashboard, name='dashboard'),
    path('api/login/', views.api_login, name='api_login'),
    path('api/logout/', views.api_logout, name='api_logout'),
]
"@

Set-Content -Path $appUrlsPath -Value $appUrlsContent

# Create views.py
$viewsPath = Join-Path $projectPath "$AppName\views.py"
$viewsContent = @"
from django.shortcuts import render, redirect
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.authentication import BasicAuthentication
from django.views.decorators.csrf import csrf_exempt
from rest_framework.response import Response
from rest_framework import status


def home(request):
    return render(request, '$AppName/index.html')


def signup(request):
    if request.method == 'POST':
        username = request.POST.get('username')
        email = request.POST.get('email')
        password = request.POST.get('password')
        
        if User.objects.filter(username=username).exists():
            return render(request, '$AppName/signup.html', {'error': 'Username already exists'})
        
        if User.objects.filter(email=email).exists():
            return render(request, '$AppName/signup.html', {'error': 'Email already exists'})
        
        user = User.objects.create_user(username=username, email=email, password=password)
        user.save()
        
        return redirect('login')
    
    return render(request, '$AppName/signup.html')


def login_view(request):
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            login(request, user)
            return redirect('dashboard')
        else:
            return render(request, '$AppName/login.html', {'error': 'Invalid credentials'})
    
    return render(request, '$AppName/login.html')


@login_required
def logout_view(request):
    logout(request)
    return redirect('home')


@login_required
def dashboard(request):
    return render(request, '$AppName/dashboard.html', {'user': request.user})


# API Endpoints with Basic Authentication
@api_view(['POST'])
@permission_classes([AllowAny])
def api_login(request):
    username = request.data.get('username')
    password = request.data.get('password')
    
    user = authenticate(request, username=username, password=password)
    
    if user is not None:
        login(request, user)
        return Response({
            'message': 'Login successful',
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email
            }
        }, status=status.HTTP_200_OK)
    else:
        return Response({
            'error': 'Invalid credentials'
        }, status=status.HTTP_401_UNAUTHORIZED)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def api_logout(request):
    logout(request)
    return Response({
        'message': 'Logout successful'
    }, status=status.HTTP_200_OK)
"@

Set-Content -Path $viewsPath -Value $viewsContent

# Create templates
# Index template
$indexTemplate = @"
<!DOCTYPE html>
<html>
<head>
    <title>Home - $ProjectName</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .nav { margin-bottom: 30px; }
        .nav a { margin-right: 15px; text-decoration: none; color: #007bff; }
        .nav a:hover { text-decoration: underline; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <div class="nav">
        {% if user.is_authenticated %}
            <a href="{% url 'dashboard' %}">Dashboard</a>
            <a href="{% url 'logout' %}">Logout</a>
        {% else %}
            <a href="{% url 'login' %}">Login</a>
            <a href="{% url 'signup' %}">Sign Up</a>
        {% endif %}
    </div>
    
    <h1>Welcome to $ProjectName</h1>
    <p>This is a Django project with Basic Authentication.</p>
    
    {% if user.is_authenticated %}
        <p>Hello, <strong>{{ user.username }}</strong>! You are logged in.</p>
    {% else %}
        <p>Please <a href="{% url 'login' %}">login</a> or <a href="{% url 'signup' %}">sign up</a>.</p>
    {% endif %}
</body>
</html>
"@

Set-Content -Path "templates\$AppName\index.html" -Value $indexTemplate

# Signup template with gradient background
$signupTemplate = @"
<!DOCTYPE html>
<html>
<head>
    <title>Sign Up - $ProjectName</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            width: 100%;
            max-width: 400px;
        }
        .nav { margin-bottom: 20px; }
        .nav a { 
            text-decoration: none; 
            color: #667eea; 
            font-size: 14px;
        }
        .nav a:hover { text-decoration: underline; }
        h2 { 
            color: #333; 
            margin-bottom: 25px;
            text-align: center;
        }
        .form-group { margin-bottom: 20px; }
        label { 
            display: block; 
            margin-bottom: 8px; 
            color: #555;
            font-size: 14px;
            font-weight: 600;
        }
        input[type="text"], input[type="email"], input[type="password"] {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 6px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        input[type="text"]:focus, input[type="email"]:focus, input[type="password"]:focus {
            outline: none;
            border-color: #667eea;
        }
        button { 
            width: 100%;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white; 
            padding: 14px; 
            border: none; 
            border-radius: 6px; 
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover { 
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4);
        }
        .error { 
            color: #e74c3c; 
            margin-bottom: 15px;
            padding: 10px;
            background: #fdf2f2;
            border-radius: 4px;
            font-size: 14px;
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: #666;
            font-size: 14px;
        }
        .footer a {
            color: #667eea;
            text-decoration: none;
            font-weight: 600;
        }
        .footer a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="nav">
            <a href="{% url 'home' %}">← Back to Home</a>
        </div>
        
        <h2>Create Account</h2>
        
        {% if error %}
            <div class="error">{{ error }}</div>
        {% endif %}
        
        <form method="post">
            {% csrf_token %}
            <div class="form-group">
                <label>Username</label>
                <input type="text" name="username" placeholder="Enter username" required>
            </div>
            <div class="form-group">
                <label>Email</label>
                <input type="email" name="email" placeholder="Enter email" required>
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" name="password" placeholder="Enter password" required>
            </div>
            <button type="submit">Sign Up</button>
        </form>
        
        <div class="footer">
            Already have an account? <a href="{% url 'login' %}">Login here</a>
        </div>
    </div>
</body>
</html>
"@

Set-Content -Path "templates\$AppName\signup.html" -Value $signupTemplate

# Login template with gradient background
$loginTemplate = @"
<!DOCTYPE html>
<html>
<head>
    <title>Login - $ProjectName</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            width: 100%;
            max-width: 400px;
        }
        .nav { margin-bottom: 20px; }
        .nav a { 
            text-decoration: none; 
            color: #11998e; 
            font-size: 14px;
        }
        .nav a:hover { text-decoration: underline; }
        h2 { 
            color: #333; 
            margin-bottom: 25px;
            text-align: center;
        }
        .form-group { margin-bottom: 20px; }
        label { 
            display: block; 
            margin-bottom: 8px; 
            color: #555;
            font-size: 14px;
            font-weight: 600;
        }
        input[type="text"], input[type="password"] {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 6px;
            font-size: 14px;
            transition: border-color 0.3s;
        }
        input[type="text"]:focus, input[type="password"]:focus {
            outline: none;
            border-color: #11998e;
        }
        button { 
            width: 100%;
            background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
            color: white; 
            padding: 14px; 
            border: none; 
            border-radius: 6px; 
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        button:hover { 
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(17, 153, 142, 0.4);
        }
        .error { 
            color: #e74c3c; 
            margin-bottom: 15px;
            padding: 10px;
            background: #fdf2f2;
            border-radius: 4px;
            font-size: 14px;
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            color: #666;
            font-size: 14px;
        }
        .footer a {
            color: #11998e;
            text-decoration: none;
            font-weight: 600;
        }
        .footer a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="nav">
            <a href="{% url 'home' %}">← Back to Home</a>
        </div>
        
        <h2>Welcome Back</h2>
        
        {% if error %}
            <div class="error">{{ error }}</div>
        {% endif %}
        
        <form method="post">
            {% csrf_token %}
            <div class="form-group">
                <label>Username</label>
                <input type="text" name="username" placeholder="Enter username" required>
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" name="password" placeholder="Enter password" required>
            </div>
            <button type="submit">Login</button>
        </form>
        
        <div class="footer">
            Don't have an account? <a href="{% url 'signup' %}">Sign up here</a>
        </div>
    </div>
</body>
</html>
"@

Set-Content -Path "templates\$AppName\login.html" -Value $loginTemplate

# Dashboard template
$dashboardTemplate = @"
<!DOCTYPE html>
<html>
<head>
    <title>Dashboard - $ProjectName</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .nav { margin-bottom: 30px; padding: 10px; background: #f8f9fa; border-radius: 4px; }
        .nav a { margin-right: 15px; text-decoration: none; color: #007bff; }
        .nav a:hover { text-decoration: underline; }
        .logout { color: #dc3545 !important; }
        .card { background: #f8f9fa; padding: 20px; border-radius: 8px; margin-top: 20px; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <div class="nav">
        <a href="{% url 'home' %}">Home</a>
        <a href="{% url 'dashboard' %}">Dashboard</a>
        <a href="{% url 'logout' %}" class="logout">Logout</a>
    </div>
    
    <h1>Dashboard</h1>
    
    <div class="card">
        <h3>Welcome, {{ user.username }}!</h3>
        <p><strong>Email:</strong> {{ user.email }}</p>
        <p><strong>User ID:</strong> {{ user.id }}</p>
        <p><strong>Date Joined:</strong> {{ user.date_joined }}</p>
    </div>
    
    <div class="card">
        <h3>API Access</h3>
        <p>You can access protected API endpoints using Basic Authentication.</p>
        <p><strong>API Login:</strong> POST /api/login/</p>
        <p><strong>API Logout:</strong> POST /api/logout/</p>
    </div>
</body>
</html>
"@

Set-Content -Path "templates\$AppName\dashboard.html" -Value $dashboardTemplate

# ==================== RUN MIGRATIONS ====================
Write-Host "`n[8/8] Running migrations..." -ForegroundColor Yellow
python manage.py migrate

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Project Location: $projectPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting server and opening browser..." -ForegroundColor Yellow

# Open browser
$serverUrl = "http://127.0.0.1:$Port/"
Start-Process $serverUrl

Write-Host "Browser opened at: $serverUrl" -ForegroundColor Green
Write-Host ""
Write-Host "Available URLs:" -ForegroundColor Yellow
Write-Host "  Home:      $serverUrl" -ForegroundColor White
Write-Host "  Sign Up:   ${serverUrl}signup/" -ForegroundColor White
Write-Host "  Login:     ${serverUrl}login/" -ForegroundColor White
Write-Host "  Dashboard: ${serverUrl}dashboard/" -ForegroundColor White
Write-Host "  Admin:     ${serverUrl}admin/" -ForegroundColor White
Write-Host ""
Write-Host "API Endpoints (Basic Auth):" -ForegroundColor Yellow
Write-Host "  POST /api/login/  - Login with username/password" -ForegroundColor White
Write-Host "  POST /api/logout/ - Logout (requires auth)" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Cyan
Write-Host ""

# Start the server
python manage.py runserver $Port