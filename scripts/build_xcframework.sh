#!/bin/bash

# 🎨 Renkli loglar
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

set -e

log_info() { echo -e "${GREEN}✅ [INFO] $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️ [WARNING] $1${NC}"; }
log_error() { echo -e "${RED}❌ [ERROR] $1${NC}"; exit 1; }
log_section() {
  echo -e "\n${CYAN}============================================"
  echo -e "🚀 $1 🚀"
  echo -e "============================================${NC}\n"
}

# 📌 Script dizinini ve proje kökünü bul
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="/Volumes/Mac/PAYLISHER-FW-IOS"
cd "$PROJECT_ROOT" || log_error "❌ Proje dizinine geçilemedi!"
log_info "📁 Çalışma dizini: $PROJECT_ROOT"

# Scheme adı sabit
SCHEME_NAME="Paylisher"

# 📌 Log Klasörü ve Dosyası
LOG_DIR="$PROJECT_ROOT/build/logs"
LOG_FILE="${LOG_DIR}/${SCHEME_NAME}_build.log"

# Log dizini oluştur (yoksa)
mkdir -p "$LOG_DIR"

# Eski log dosyası varsa sil
rm -f "$LOG_FILE"
touch "$LOG_FILE"

# Build klasörleri
BUILD_DIR="$PROJECT_ROOT/build"
XCFRAMEWORK_OUTPUT="$BUILD_DIR/${SCHEME_NAME}.xcframework"
IOS_ARCHIVE="$BUILD_DIR/ios.xcarchive"
SIMULATOR_ARCHIVE="$BUILD_DIR/ios_simulator.xcarchive"

# 📌 Başlangıç temizliği
log_section "🔄 [${SCHEME_NAME}] Temizleme işlemleri başlatılıyor"

# Xcode build cache temizle
log_info "🧹 [${SCHEME_NAME}] Xcode cache temizleniyor..."
xcodebuild clean -project Paylisher.xcodeproj -scheme "$SCHEME_NAME" 2>&1 | tee -a "$LOG_FILE" || true

# Eski XCFramework'ü yedekle
if [ -d "$XCFRAMEWORK_OUTPUT" ]; then
    BACKUP_NAME="${SCHEME_NAME}_$(date +%Y%m%d_%H%M%S).xcframework"
    log_warning "⚠️ Mevcut XCFramework yedekleniyor: $BACKUP_NAME"
    mv "$XCFRAMEWORK_OUTPUT" "$BUILD_DIR/$BACKUP_NAME"
fi

# Eski archive'ları temizle
rm -rf "$IOS_ARCHIVE" "$SIMULATOR_ARCHIVE"

# 📌 1️⃣ iOS için archive oluştur (arm64)
log_section "📦 [${SCHEME_NAME}] iOS cihazları için archive oluşturuluyor (arm64)"
xcodebuild archive \
    -project Paylisher.xcodeproj \
    -scheme "$SCHEME_NAME" \
    -destination "generic/platform=iOS" \
    -archivePath "$IOS_ARCHIVE" \
    -sdk iphoneos \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS="arm64" 2>&1 | tee -a "$LOG_FILE" || log_error "❌ iOS archive oluşturulamadı!"

log_info "✅ iOS archive başarıyla oluşturuldu: $IOS_ARCHIVE"

# 📌 2️⃣ iOS Simulator için archive oluştur (x86_64, arm64)
log_section "📦 [${SCHEME_NAME}] iOS Simulator için archive oluşturuluyor (x86_64, arm64)"
xcodebuild archive \
    -project Paylisher.xcodeproj \
    -scheme "$SCHEME_NAME" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$SIMULATOR_ARCHIVE" \
    -sdk iphonesimulator \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS="x86_64 arm64" 2>&1 | tee -a "$LOG_FILE" || log_error "❌ iOS Simulator archive oluşturulamadı!"

log_info "✅ iOS Simulator archive başarıyla oluşturuldu: $SIMULATOR_ARCHIVE"

# 📌 3️⃣ XCFramework oluştur
log_section "🛠️ [${SCHEME_NAME}] XCFramework oluşturuluyor"
xcodebuild -create-xcframework \
    -framework "$IOS_ARCHIVE/Products/Library/Frameworks/${SCHEME_NAME}.framework" \
    -framework "$SIMULATOR_ARCHIVE/Products/Library/Frameworks/${SCHEME_NAME}.framework" \
    -output "$XCFRAMEWORK_OUTPUT" 2>&1 | tee -a "$LOG_FILE" || log_error "❌ XCFramework oluşturulamadı!"

log_info "✅ XCFramework başarıyla oluşturuldu: $XCFRAMEWORK_OUTPUT"

# 📌 4️⃣ Swift Interface dosyalarını kontrol et
log_section "🔍 Swift Interface Dosyaları Kontrolü"
SWIFTINTERFACE_FILES=$(find "$XCFRAMEWORK_OUTPUT" -name "*.swiftinterface" 2>/dev/null)

if [ -n "$SWIFTINTERFACE_FILES" ]; then
    log_info "✅ Swift interface dosyaları bulundu:"
    echo "$SWIFTINTERFACE_FILES" | while read -r file; do
        echo "  📄 $file"
    done
    
    # _WebKit_SwiftUI kontrolü
    log_info "🔎 _WebKit_SwiftUI import kontrolü yapılıyor..."
    if grep -r "_WebKit_SwiftUI" "$XCFRAMEWORK_OUTPUT" 2>/dev/null; then
        log_warning "⚠️ _WebKit_SwiftUI import'u bulundu! Bu geriye dönük uyumluluk sorununa yol açabilir."
    else
        log_info "✅ _WebKit_SwiftUI import'u bulunamadı. Geriye dönük uyumluluk iyi durumda."
    fi
else
    log_warning "⚠️ Swift interface dosyası bulunamadı."
fi

# 📌 5️⃣ XCFramework bilgilerini göster
log_section "📊 XCFramework Detayları"
log_info "📦 Framework yapısı:"
tree -L 3 "$XCFRAMEWORK_OUTPUT" 2>/dev/null || find "$XCFRAMEWORK_OUTPUT" -maxdepth 3 -print

# Framework boyutunu göster
FRAMEWORK_SIZE=$(du -sh "$XCFRAMEWORK_OUTPUT" | cut -f1)
log_info "📏 XCFramework boyutu: $FRAMEWORK_SIZE"

# Static library kontrolü
log_info "🔍 Library türü kontrolü:"
find "$XCFRAMEWORK_OUTPUT" -name "Paylisher" -type f | while read -r binary; do
    FILE_TYPE=$(file "$binary")
    echo "  📄 $binary"
    echo "     ➜ $FILE_TYPE"
done

# 📌 6️⃣ Archive dosyalarını temizle (opsiyonel, kapatılabilir)
log_info "🧹 Archive dosyaları temizleniyor..."
rm -rf "$IOS_ARCHIVE" "$SIMULATOR_ARCHIVE"

# 📌 ✅ İşlem tamamlandı
log_section "✅ [${SCHEME_NAME}] İşlem tamamlandı!"
echo -e "${BOLD}${GREEN}🎉 XCFramework başarıyla oluşturuldu:${NC}"
echo -e "${BOLD}   📦 $XCFRAMEWORK_OUTPUT${NC}"
echo -e "\n${CYAN}📝 Build log:${NC} $LOG_FILE"
echo -e "${CYAN}💾 Boyut:${NC} $FRAMEWORK_SIZE\n"
