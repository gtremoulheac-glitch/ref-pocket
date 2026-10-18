@echo off
chcp 65001 >nul
title Ref Pocket - Publication sur Vercel
echo.
echo  Publication de Ref Pocket sur Vercel...
echo.
where node >nul 2>nul
if errorlevel 1 (
  echo  Node.js n'est pas installé. Installe la version LTS depuis https://nodejs.org puis relance ce fichier.
  echo.
  pause
  exit /b 1
)
cd /d "%~dp0web"
call npx --yes vercel --prod
echo.
echo  Terminé. L'adresse du site est affichée ci-dessus, à la ligne Production ou Aliased.
echo.
pause
