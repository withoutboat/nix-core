{ stdenv, nixos-bootstrapper-src }:

stdenv.mkDerivation {
  pname = "nixos-bootstrapper";
  version = "0.1.1";
  
  src = nixos-bootstrapper-src;

  # Работаем в корне директории распаковки
  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    
    echo "=================================================="
    echo "СТРУКТУРА РАСПАКОВАННОГО АРХИВА В ПЕСОЧНИЦЕ NIX:"
    echo "=================================================="
    ls -R
    echo "=================================================="

    # Временный гибкий поиск, чтобы билд прошел в любом случае
    TARGET_BIN=$(find . -type f -name "*nixos-bootstrapper*" | head -n 1)
    
    if [ -z "$TARGET_BIN" ]; then
      echo "Ошибка: Не удалось найти файл по маске *nixos-bootstrapper*!"
      exit 1
    fi
    
    echo "Найден бинарник: $TARGET_BIN -> Копируем в $out/bin/nixos-bootstrapper"
    cp "$TARGET_BIN" $out/bin/nixos-bootstrapper
    chmod +x $out/bin/nixos-bootstrapper
  '';
}
