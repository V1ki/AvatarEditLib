//
//  AvatarEditView.swift
//  AvatarEditLib
//
//  Created by Vk on 2019/12/21.
//  Copyright © 2019 V1ki. All rights reserved.
//

import SwiftUI
let screen_w = UIScreen.main.bounds.width
let screen_h = UIScreen.main.bounds.height
let widget_w = screen_w - 20 * 2

@available(iOS 13.0, *)
public struct AvatarView : View {
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @State var defaultImage : UIImage// = UIImage(named:"avatar")!
    @State var choosedImg : UIImage? = nil
    @State var showAlert : Bool = false
    @State var showEditor : Bool = false
    
    public init(defaultImage : UIImage){
        self.defaultImage = defaultImage
    }
    
    public var body : some View {
        
        NavigationView {
            Image(uiImage: self.choosedImg == nil ? defaultImage : self.choosedImg!)
                .resizable()
                .aspectRatio( self.choosedImg == nil ? 1 : self.choosedImg!.size.width / self.choosedImg!.size.height , contentMode: .fit)
                .frame(width: screen_w)
                .onTapGesture { self.showAlert.toggle() }
                .actionSheet(isPresented: self.$showAlert) {
                    ActionSheet(title: Text("修改头像"),
                                buttons:[
                                    .default(Text("从相册选取"), action: {
                                        // 记得添加权限。
                                        self.showEditor.toggle()
                                    })
                        ]
                    )
            }.sheet(isPresented: self.$showEditor) {
                AvatarEditView(self.$choosedImg)
            } .navigationBarTitle("选择头像", displayMode: .inline)
                .navigationBarItems(trailing:
                    Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("确定")
                    }
            )
        }
    }
}

@available(iOS 13.0, *)
let topSpacing: CGFloat = UIApplication.shared.windows[0].safeAreaInsets != UIEdgeInsets.zero ? 54 : 40
@available(iOS 13.0, *)
public struct AvatarEditView: View {
    
    enum DragState {
        case inactive
        case scaling(scale:CGFloat)
        case dragging(translation: CGSize)
        
        var translation: CGSize {
            switch self {
            case .inactive, .scaling(_):
                return .zero
            case .dragging(let translation):
                return translation
            }
        }
        
        var scale : CGFloat {
            switch self {
            case .scaling(let scale):
                return scale
            case .inactive, .dragging( _):
                return 1
            }
        }
        
        var isActive: Bool {
            switch self {
            case .inactive:
                return false
            case .scaling(_), .dragging:
                return true
            }
        }
        
        var isDragging: Bool {
            switch self {
            case .inactive, .scaling(_):
                return false
            case .dragging:
                return true
            }
        }
    }
    
    @GestureState var dragState = DragState.inactive
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    @State var originScaleVal : CGFloat = 1
    @State var imgScaleVal: CGFloat = 1
    @State var image : UIImage? = nil
    @Binding var choosedImg : UIImage?
    @State var viewState = CGSize(width: 0, height: 0)
    @State var btnDisabled : Bool = false
    @State var imgViewSize = CGSize(width:widget_w, height: 0)
    @State var aspectRatio : CGFloat? = nil
    // 因为是使用的Sheet 模式。 所以这个地方不能 用Screen_h
    // 需要获取当前视图的 高度？ GeometryReader
    
    let cropRect : CGRect = CGRect(x: 20, y:  ( screen_h - topSpacing - widget_w) / 2, width: widget_w, height: widget_w)
    
    public var body: some View {
        
        let magnificationDrag = MagnificationGesture()
            .simultaneously(with: DragGesture())
            .updating($dragState) { value , state , transaction in
                if value.first == nil && value.second == nil {
                    state = .inactive
                    return
                }
                if let scale = value.first {
                    state = .scaling(scale: scale)
                }
                if let drag = value.second {
                    state = .dragging(translation: drag.translation)
                }
        }.onEnded{ value in
            if let scale = value.first {
                var scaleVal = self.imgScaleVal * scale
                scaleVal = scaleVal < 1 ? 1 : scaleVal
                
                let tempImgScaleVal = self.imgScaleVal
                self.imgScaleVal = scaleVal
                if self.imgScaleVal < tempImgScaleVal {
                    // 如果是缩放的话，才需要进行处理。如果是放大的话 ，是不需要处理的 。
                    self.calcOffset(width: self.viewState.width, height: self.viewState.height)
                }
                
            }
            if let drag = value.second {
                let width = self.viewState.width + drag.translation.width
                let height = self.viewState.height + drag.translation.height
                
                self.calcOffset(width: width, height: height)
                
                
                // 这里需要记住。 缩放会导致 偏移也会有相应的缩放，是因为我把缩放放在o偏移后面，所以导致的问题.
                // 缩放如果和偏移一起使用的时候，记住先缩放，再偏移。。。 时刻记住SwiftUI中的先后顺序
                
            }
            
        }
        
        return Group{
            if self.image == nil {
                
                PhotoPickerView { image in
                    // 横向的图片显示有问题
                    // 所以在加载图片的时候，如果图片的尺寸比较大，则需要进行缩放，或者移动，以找到一个合适的位置来展示。
                    if image != nil {
                        
                        let size = image!.size
                        self.initScale(size)
                    }
                    
                    self.image = image
                }
            }
            else {
                
                NavigationView {
                    ZStack {
                        Image(uiImage: self.image!)
                            .resizable()
                            .aspectRatio(self.aspectRatio, contentMode: .fit)
                            .scaleEffect(imgScaleVal * dragState.scale)
                            .offset(x: viewState.width + dragState.translation.width, y: viewState.height + dragState.translation.height)
                            .modifier(ImageFrameModifier(size:self.imgViewSize ))
                            .animation(.linear)
                        
                        // 这里 有点纠结，Path 是没有动画的。所以如果即使加上了Animation 也应该没有效果。 这里有一点需要记住，在Path中的话，是没有动画效果，但是我们这个是在Path 外面的。
                        
                        GeometryReader{p in
                            self.getModalPath(proxy: p)
                        }
                        .frame(maxWidth : .infinity ,maxHeight : .infinity )
                        
                    }
                    .edgesIgnoringSafeArea(.all)
                    .frame(maxWidth : .infinity ,maxHeight: .infinity).gesture( magnificationDrag )
                    .navigationBarTitle("头像编辑", displayMode: .inline)
                    .navigationBarItems(
                        leading:(
                            
                            Button(action: {
                                self.presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("取消")
                            }
                        ),
                        
                        trailing:
                        Button(action: {
                            self.selectedImage()
                        }) {
                            Text("完成")
                        }.disabled(self.btnDisabled)
                    )
                }
            }
        }
        
    }
    
    
    init(_ choosedImg: Binding<UIImage?>){
        self._choosedImg = choosedImg
    }
    
    func selectedImage() {
        self.btnDisabled.toggle()
        // 将Image的坐标偏移转换成 图片数据中实际偏移
        let size = self.image!.size
        var topOffset : CGFloat = 0
        var leftOffset : CGFloat = 0
        var imgScale : CGFloat = 1
        
        if self.imgViewSize.width == widget_w {
            
            let tempScale = widget_w / size.width
            let imgWidth = widget_w * self.imgScaleVal / self.originScaleVal
            let imgHeight = size.height * tempScale * self.imgScaleVal
            
            
            leftOffset =  (imgWidth - widget_w) / 2
            topOffset =  (imgHeight - widget_w) / 2
            
            // 将Button 禁用。这里就要考虑一下在SwiftUI中，如何禁用Button的点击事件了。有没有系统方法.还是要新建一个变量。。
            // 文档中提到了、外层View 的disable 会禁用内层View的，所以使用的时候需要小心、
            
            imgScale =   size.width /  (widget_w *  self.imgScaleVal  / self.originScaleVal)
        }
        else {
            
            
            let tempScale =  widget_w / self.image!.size.height
            let imgWidth = self.image!.size.width * tempScale * self.imgScaleVal / self.originScaleVal
            let imgHeight = widget_w * self.imgScaleVal / self.originScaleVal
            
            
            
            leftOffset =  (imgWidth - widget_w) / 2
            topOffset =  (imgHeight - widget_w) / 2
            imgScale =   size.height /  (widget_w *  self.imgScaleVal  / self.originScaleVal)
        }
        
        print("-- leftOffset:\(leftOffset) - topOffset:\(topOffset) - :\(self.viewState) - imgScale:\(imgScale)")
        // 图片数据处理可以放到 其他线程处理，不要占用主线程资源
        self.image!.cropImg( CGSize(width: leftOffset - self.viewState.width ,height: topOffset - self.viewState.height) , imgScale ) {img in
            self.btnDisabled = false
            self.choosedImg = img
            if img != nil {
                
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    func getModalPath(proxy: GeometryProxy) -> some View {
        let cropRect : CGRect = CGRect(x: 20, y:  ( proxy.size.height - widget_w) / 2, width: widget_w, height: widget_w)
        return ZStack {
            Path { p in
                p.addRect( cropRect)
                p.addRect( UIScreen.main.bounds)
            }
            .fill(Color.init(.sRGB, white: 0, opacity: dragState.isDragging ? 0 : 0.6), style: .init(eoFill: true, antialiased: false))
            .animation(.easeIn)
            .frame(maxWidth : .infinity)
            
            Path {p in
                
                for i in 0...3 {
                    
                    p.move(to: CGPoint(x: cropRect.minX,y :cropRect.minY + CGFloat(i) * (widget_w / 3)  ) )
                    p.addLine(to: CGPoint(x: cropRect.maxX,y :cropRect.minY + CGFloat(i) *  (widget_w / 3))  )
                }
                
                for i in 0...3 {
                    
                    p.move(to: CGPoint(x: cropRect.minX  + CGFloat(i) * (widget_w / 3) ,y :cropRect.minY) )
                    p.addLine(to: CGPoint(x: cropRect.minX  + CGFloat(i) * (widget_w / 3)   ,y :cropRect.maxY  ) )
                }
                
                
            }.stroke(lineWidth: 1 ).foregroundColor(Color.white)
        }
        
    }
    
    func initScale(_ size: CGSize){
        
        self.aspectRatio = size.width /  size.height
        
        // 如果尺寸较大的情况。 首先。保证小的一边满足 widget_w
        if size.width < size.height {
            
            
            var fitImageScale = widget_w / size.width
            let fitImageHeight = size.height * fitImageScale
            
            if fitImageHeight < widget_w {
                // 如果高度不足。则将高度适应到widget_w ，宽度变化
                fitImageScale = widget_w / size.height
                self.imgScaleVal = fitImageScale
                self.originScaleVal = self.imgScaleVal
                // 超出屏幕范围了。
                self.imgViewSize = CGSize(width : 0 ,height:widget_w )
            }
            else {
                self.imgViewSize = CGSize(width : widget_w ,height:fitImageHeight )
            }
        }
        else {
            var fitImageScale = widget_w / size.height
            let fitImageWidth = size.width * fitImageScale
            
            if fitImageWidth < widget_w {
                // 如果高度不足。则将高度适应到widget_w ，宽度变化
                fitImageScale =  widget_w / size.width
                self.imgScaleVal = fitImageScale
                self.originScaleVal = self.imgScaleVal
                
                self.imgViewSize = CGSize(width : 0 ,height:widget_w)
            }
            else {
                if fitImageWidth >= screen_w {
                    // 如果超出屏幕范围的话，需要使用缩放来解决问题。
                    self.imgScaleVal = fitImageWidth / screen_w
                    
                    self.originScaleVal = self.imgScaleVal
                    
                }
                self.imgViewSize = CGSize(width : fitImageWidth  ,height:widget_w )
                
            }
            
        }
        
        print("---size:\(size) imgScaleVal:\(self.imgScaleVal) -- imgViewSize:\(self.imgViewSize)")
    }
    
    func calcOffset(width tmp_w: CGFloat , height tmp_h: CGFloat) {
        var width = tmp_w
        var height = tmp_h
        
        if self.imgViewSize.width == widget_w {
            let tempScale = widget_w / self.image!.size.width
            let imgWidth = widget_w * self.imgScaleVal / self.originScaleVal
            let imgHeight = self.image!.size.height * tempScale * self.imgScaleVal
            let topOffset = (imgHeight - widget_w) / 2
            let bottomOffset = -topOffset
            let leftOffset = (imgWidth - widget_w) / 2
            let rightOffset = -leftOffset
            
            
            width = width > leftOffset ? leftOffset : width
            
            
            if width > leftOffset {
                width = leftOffset
            } else if width < rightOffset {
                width = rightOffset
            }
            if height > topOffset {
                height = topOffset
            } else if height < bottomOffset {
                height = bottomOffset
            }
            
            self.viewState.width = width
            self.viewState.height = height
            print("--- leftOffset:\(leftOffset) -- topOffset:\(topOffset) -- viewState:\(self.viewState)")
        }
        else {
            // 宽度自适应、在 宽高比 比较大的时候，这个大的定义为超过  screen_w / widget_w 的时候。
            
            let tempScale =  widget_w / self.image!.size.height
            let imgWidth = self.image!.size.width * tempScale * self.imgScaleVal / self.originScaleVal
            let imgHeight = widget_w * self.imgScaleVal / self.originScaleVal
            // 此时这里的缩放值不对。
            
            let leftOffset =  (imgWidth - widget_w) / 2
            let topOffset =  (imgHeight - widget_w) / 2
            let rightOffset = -leftOffset
            let bottomOffset = -topOffset
            
            width = width > leftOffset ? leftOffset : width
            
            
            if width > leftOffset {
                width = leftOffset
            } else if width < rightOffset {
                width = rightOffset
            }
            
            if height > topOffset {
                height = topOffset
            } else if height < bottomOffset {
                height = bottomOffset
            }
            
            self.viewState.width = width
            self.viewState.height = height
            print("--- leftOffset:\(leftOffset) -- topOffset:\(topOffset) -- viewState:\(self.viewState) -- imgSize:\(imgWidth),\(imgHeight)")
        }
    }
    
}
@available(iOS 13.0, *)
struct ImageFrameModifier : ViewModifier {
    
    let size: CGSize
    
    func body(content: Self.Content) -> some View {
        if size.width == widget_w {
            return content.frame(width: widget_w )
        }
        else {
            return content.frame(height: widget_w)
        }
        
    }
    
}
extension UIImage {
    
    // 基于目前的 API，我们可以考虑使用Binding来返回值，而不是用Callback ,这里还是需要使用Callback会好些。。。 简直打脸
    func cropImg(_ offset: CGSize ,_ zoomScale: CGFloat , _ handler : @escaping (UIImage?) -> Void  ){
        
        DispatchQueue.global(qos: .default).async {
            // 首先计算原图的缩放大小。
            
            let imgCropRect = CGRect(x: offset.width, y: offset.height, width: (widget_w), height: (widget_w))
            // ... 你是怎么算出一个宽高不一样的 值的。。
            var cropRect = imgCropRect.applying( CGAffineTransform(scaleX: zoomScale, y: zoomScale) )
            let x = cropRect.minX , y = cropRect.minY ,width = cropRect.width ,height = cropRect.height
            switch self.imageOrientation  {
            case .left , .leftMirrored :
                cropRect.origin.x = floor(self.size.height - height - y)
                cropRect.origin.y = x
                break
            case .right , .rightMirrored :
                cropRect.origin.x = y
                cropRect.origin.y = floor(self.size.width - width - x)
                break
                
            case .down ,.downMirrored:
                cropRect.origin.x = floor(self.size.width - width - x)
                cropRect.origin.y = floor(self.size.height - height - y)
                break
            default: break ;
                
            }
            
            
            if let cgimg = self.cgImage {
                let img = UIImage(cgImage: cgimg.cropping(to: cropRect)! ,scale: self.scale ,orientation: self.imageOrientation)
                print("imgCropRect:\(imgCropRect) cropRect:\(cropRect) --- img.size:\(img.size) -- Orientation: \(self.imageOrientation.rawValue)")
                handler(img)
            }
            else {
                handler(nil)
            }
            
        }
    }
    
    
}
