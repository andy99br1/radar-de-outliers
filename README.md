# Radar de Outliers

App Android que encontra vídeos gringos de ciência e curiosidade que estouraram acima da média do próprio canal (breakout) e confere se o tema já foi feito no YouTube brasileiro. Usa a YouTube Data API v3 com a chave do próprio usuário.

## Estrutura
- `assets/index.html`: interface e lógica (HTML/CSS/JS) mostrada num WebView
- `assets/fonts/`: fontes embutidas (Big Shoulders Display, Archivo, IBM Plex Mono — licença OFL)
- `src/.../MainActivity.java`: WebView, ponte HTTP para a API do Google, tema escuro e compartilhar
- `res/`: ícone e tema
- `build.sh`: compila sem Gradle (aapt2 + javac + d8 + apksigner)

## Compilar
Precisa de JDK 17+, Android build-tools 35 e platform android-35. Aponte `SDK` para a pasta que contém `android-15/` (build-tools) e `android-35/` (platform):

    SDK=/caminho/do/sdk ./build.sh

## Assinatura
O app é assinado por `radar.keystore`, que **não fica neste repositório**. Guarde o arquivo e a senha fora do GitHub. Para compilar, coloque o arquivo na raiz do projeto e informe a senha:

    KS_PASS=sua-senha SDK=/caminho/do/sdk ./build.sh

Atualizações só instalam por cima do app se forem assinadas com essa mesma chave.
