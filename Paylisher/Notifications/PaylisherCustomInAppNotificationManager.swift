//
//  PaylisherCustomInAppNotificationManager.swift
//  Paylisher
//
//  Created by Rasim Burak Kaya on 10.04.2025.
//

import Foundation
import UIKit

//@available(iOSApplicationExtension, unavailable)
public class PaylisherCustomInAppNotificationManager {
    
    public static let shared = PaylisherCustomInAppNotificationManager()
    
    
    
    private init() {
        
    }
    
    public func parseInAppPayload(from userInfo: [AnyHashable: Any], windowScene: UIWindowScene?) -> CustomInAppPayload? {
        
        guard let stringKeyedInfo = userInfo as? [String: Any] else {
            print("userInfo'yu [String:Any] olarak cast edemedim.")
            return nil
        }
        
        
        var normalizedInfo = [String: Any]()
        
        for (key, value) in stringKeyedInfo {
            
            if key == "layouts" {
                
                if let layoutsString = value as? String {
                    
                    if let data = layoutsString.data(using: .utf8) {
                        do {
                            
                            if let arrayObject = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                                normalizedInfo[key] = arrayObject
                            } else {
                                
                                print("layouts string, fakat array'e parse edilemedi")
                                
                                normalizedInfo[key] = value
                            }
                        } catch {
                            print("layouts'u parse ederken hata:", error)
                            normalizedInfo[key] = value
                        }
                    } else {
                        
                        normalizedInfo[key] = value
                    }
                }
                
                else {
                    normalizedInfo[key] = value
                }
            } else {
                
                normalizedInfo[key] = value
            }
        }
        
        
        do {
            let data = try JSONSerialization.data(withJSONObject: normalizedInfo, options: [])
            
            let decoder = JSONDecoder()
            let payload = try decoder.decode(CustomInAppPayload.self, from: data)
            return payload
        } catch {
            print("InAppPayload decode error:", error)
            return nil
        }
    }
    
    public func customInAppFunction(userInfo: [AnyHashable: Any], windowScene: UIWindowScene?) {
        
        guard let payload = parseInAppPayload(from: userInfo, windowScene: windowScene) else {
            print("Payload parse edilemedi.")
            return
        }
        
        
        let lang = payload.defaultLang ?? "en"
        //  let layoutType = payload.layoutType ?? "no-type"
        // print("Default Lang:", lang)
        // print("Layout Type:", layoutType)
        
        
        if let layouts = payload.layouts, !layouts.isEmpty {
            let firstLayout = layouts[0]
            
            
            
            print("--------------Style---------------")
            
            if let style = firstLayout.style, let close = firstLayout.close, let extra = firstLayout.extra, let blocks = firstLayout.blocks {
                print("navigationalArrows: ", style.navigationalArrows ?? "")
                print("radius: ", style.radius ?? "")
                print("bgColor: ", style.bgColor ?? "")
                print("bgImage: ", style.bgImage ?? "")
                print("bgImageMask: ", style.bgImageMask ?? "")
                print("bgImageColor: ", style.bgImageColor ?? "")
                print("verticalPosition: ", style.verticalPosition ?? "")
                print("horizontalPosition: ", style.horizontalPosition ?? "boş")
                print("active: ", close.active ?? "")
                
                let styleVC = StyleViewController(style: style, close: close, extra: extra, blocks: blocks, defaultLang: lang)
                //#if IOS
                //                styleVC.modalPresentationStyle = .overFullScreen
                
                //                if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                //                    rootVC.present(styleVC, animated: false)
                //                }
                
                if windowScene != nil,
                   let keyWindow = windowScene?.windows.first(where: { $0.isKeyWindow }),
                   let rootVC = keyWindow.rootViewController {
                    rootVC.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
                    rootVC.present(styleVC, animated: false)
                }
                //#endif
                
            }
            
            
            
            print("----------------------------------")
            print("--------------Close---------------")
            
            if let close = firstLayout.close {
                // print("active: ", close.active ?? "")
                print("type: ", close.type ?? "")
                print("position: ", close.position ?? "")
                print("iconColor: ", close.icon?.color ?? "")
                print("iconStyle: ", close.icon?.style ?? "")
                print("textLabel: ", close.text?.label![lang] ?? "")
                print("textFontSize: ", close.text?.fontSize ?? "")
                print("textColor: ", close.text?.color ?? "")
                
            }
            
            print("----------------------------------")
            print("--------------Extra---------------")
            
            if let extra = firstLayout.extra {
                
                print("transition: ", extra.transition ?? "")
                print("bannerAction: ", extra.banner?.action ?? "")
                print("bannerDuration: ", extra.banner?.duration ?? "")
                print("overlayAction: ", extra.overlay?.action ?? "")
                print("overlayColor: ", extra.overlay?.color ?? "")
                
            }
            
            print("----------------------------------")
            print("--------------Blocks---------------")
            
            if let blocks = firstLayout.blocks {
                print("blocksLayer:", blocks.align ?? "")
                
                if let blockArray = blocks.order {
                    for block in blockArray {
                        switch block {
                        case .image(let imageBlock):
                            
                            print("--------------Image Block---------------")
                            print("typeImage: ", imageBlock.type ?? "")
                            print("orderImage: ", imageBlock.order ?? "")
                            print("urlImage: ", imageBlock.url ?? "")
                            print("altImage: ", imageBlock.alt ?? "")
                            print("linkImage: ", imageBlock.link ?? "boş")
                            print("radiusImage: ", imageBlock.radius ?? "")
                            print("marginImage: ", imageBlock.margin ?? "")
                            
                            
                        case .spacer(let spacerBlock):
                            
                            print("----------------------------------")
                            print("--------------Spacer Block---------------")
                            print("typeSpacer: ", spacerBlock.type ?? "")
                            print("orderSpacer: ", spacerBlock.order ?? "")
                            print("verticalSpacingSpacer: ", spacerBlock.verticalSpacing ?? "")
                            print("fillAvailableSpacingSpacer: ", spacerBlock.fillAvailableSpacing ?? "")
                            
                            
                        case .text(let textBlock):
                            print("----------------------------------")
                            print("--------------Text Block---------------")
                            print("typeText: ", textBlock.type ?? "")
                            print("orderText: ", textBlock.order ?? "")
                            print("contentText: ", textBlock.content![lang]!)
                            print("actionText: ", textBlock.action ?? "")
                            print("fontFamilyText: ", textBlock.fontFamily ?? "")
                            print("fontWeightText: ", textBlock.fontWeight ?? "")
                            print("fontSizeText: ", textBlock.fontSize ?? "")
                            print("underscoreText: ", textBlock.underscore ?? "")
                            print("italicText: ", textBlock.italic ?? "")
                            print("colorText: ", textBlock.color ?? "")
                            print("textAlignmentText: ", textBlock.textAlignment ?? "")
                            print("horizontalMarginText: ", textBlock.horizontalMargin ?? "")
                            
                            
                        case .buttonGroup(let buttonGroupBlock):
                            print("----------------------------------")
                            print("--------------ButtonGroup Block---------------")
                            print("typeButtonGroup: ", buttonGroupBlock.type ?? "")
                            print("orderButtonGroup: ", buttonGroupBlock.order ?? "")
                            print("buttonGroupTypeButtonGroup: ", buttonGroupBlock.buttonGroupType ?? "")
                            
                            if let buttonsArray = buttonGroupBlock.buttons{
                                
                                for button in buttonsArray {
                                    
                                    print("labelButtonGroup: ", button.label![lang]!)
                                    print("actionButtonGroup: ", button.action ?? "")
                                    print("fontFamilyButtonGroup: ", button.fontFamily ?? "")
                                    print("fontWeightButtonGroup: ", button.fontWeight ?? "")
                                    print("fontSizeButtonGroup: ", button.fontSize ?? "")
                                    print("underscoreButtonGroup: ", button.underscore ?? "")
                                    print("italicButtonGroup: ", button.italic ?? "")
                                    print("textColorButtonGroup: ", button.textColor ?? "")
                                    print("backgroundColorButtonGroup: ", button.backgroundColor ?? "")
                                    print("borderColorButtonGroup: ", button.borderColor ?? "")
                                    print("borderRadiusButtonGroup: ", button.borderRadius ?? "")
                                    print("horizontalSizeButtonGroup: ", button.horizontalSize ?? "")
                                    print("verticalSizeButtonGroup: ", button.verticalSize ?? "")
                                    print("buttonPositionButtonGroup: ", button.buttonPosition ?? "")
                                    print("marginButtonGroup: ", button.margin ?? "")
                                    print("----------------------------------")
                                }
                            }
                        }
                    }
                }
            }
            
            
        }
    }
}
