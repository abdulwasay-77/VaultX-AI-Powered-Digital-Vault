# PyInstaller spec file for VaultX backend
# Build with:  pyinstaller vaultx_backend.spec
# Output:      dist/vaultx_backend/vaultx_backend.exe  (plus its supporting files)

a = Analysis(
    ['run_backend.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('sqlite_schema.sql', '.'),   # bundled so the exe can create the db on first run
    ],
    hiddenimports=[
        # uvicorn/starlette use dynamic imports PyInstaller can't see by itself
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
        'app.main1',
        'app.routes',
        'app.services',
        'app.utils',
        # passlib picks its hash-scheme module dynamically at runtime based on
        # a string name, so PyInstaller's static scan can't discover it on its own.
        'passlib.handlers.sha2_crypt',
        'passlib.handlers.digests',
        'passlib.handlers.misc',
    ],
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='vaultx_backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,         # hidden window now that everything's confirmed working
    disable_windowed_traceback=False,
    icon='vaultx_icon.ico',
    version='version_info.txt',
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='vaultx_backend',
)
