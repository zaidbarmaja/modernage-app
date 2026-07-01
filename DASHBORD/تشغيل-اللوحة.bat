@echo off
title Asr Al-Hadatha - Admin Dashboard (Local Server)
cd /d "%~dp0"
echo =====================================================
echo   عصر الحداثة - لوحة تحكم مدير النظام
echo   يبدأ خادم محلي ويفتح المتصفح تلقائيا.
echo   ابق هذه النافذة مفتوحة اثناء الاستخدام.
echo =====================================================
start "" http://localhost:8010
where python >nul 2>nul && (python -m http.server 8010) || (py -m http.server 8010)
pause
