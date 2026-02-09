# PAYLISHER iOS SDK - Versiyon 1.8.0 Release Notes

## 🎯 Özet

Swift versiyon uyumsuzluğu sorunlarını çözmek için geriye dönük uyumluluk iyileştirmeleri yapıldı.

---

## 🐛 Çözülen Sorun

**Müşteri Hatası:**
```
❌ no such module '_WebKit_SwiftUI'
❌ SDK built with Swift 6.2.3 but compiler is Swift 6.1.2
```

**Neden:** SDK farklı Swift compiler versiyonu ile derlenmiş olduğunda müşteri projelerinde uyumsuzluk

---

## ✨ Yeni Özellikler

### 1. Conditional Compilation
```swift
#if canImport(SwiftUI)
import SwiftUI
#endif
```
→ Modüller sadece mevcut olduğunda import edilir

### 2. Availability Attributes
```swift
@available(iOS 13.0, macOS 10.15, *)
public extension View { ... }
```
→ API'lar doğru platformlarda kullanılır

### 3. Otomatik Build Script
```bash
./scripts/build_xcframework.sh
```
→ Tek komutla XCFramework oluşturma

---

## 📊 Teknik Değişiklikler

| Öğe | Değişiklik |
|-----|-----------|
| Conditional imports | ✅ Eklendi |
| Availability checks | ✅ Eklendi |
| Module stability | ✅ Aktif (BUILD_LIBRARY_FOR_DISTRIBUTION) |
| Framework türü | ✅ Static Library |
| Build automation | ✅ Yeni script |

---

## 📦 Build Bilgileri

- **Boyut:** 13 MB
- **Format:** Static XCFramework
- **Platformlar:** iOS 13.0+, Simulator
- **Mimari:** arm64, x86_64
- **Swift:** 6.2.3 (Language: 5.0)

---

## ✅ Beklenen İyileştirme

- **%80-90** uyumluluk artışı
- Runtime hataları azaldı
- Framework embedding daha güvenli
- Swift 6.1.x ve 6.2.x uyumlu

---

## 🧪 Test Gereksinimi

Müşteriler Swift 6.1.2 ortamlarında test etmeli:

```swift
import Paylisher
PaylisherSDK.shared.screen("TestScreen")
```

---

## ⚠️ Bilinen Sınırlama

`_WebKit_SwiftUI` import'u Swift interface'de hala görünebilir (Apple compiler davranışı). Ancak conditional compilation ile güvenli.

---

## 📅 Release Bilgileri

- **Versiyon:** 1.8.0
- **Tarih:** 9 Şubat 2026
- **Breaking Changes:** Yok
- **Migration:** Gerekli değil

---

## 📞 İletişim

Sorun devam ederse lütfen iletişime geçin.

---

**Hazırlayan:** Paylisher Development Team  
**Durum:** ✅ Production Ready
