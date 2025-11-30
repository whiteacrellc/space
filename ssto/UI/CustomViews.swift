
import UIKit

class DraggableControlPoint: UIView {
    
    var onMoved: ((CGPoint) -> Void)?
    var isConstrainedToVertical = false
    var isConstrainedToHorizontal = false
    var offset: CGFloat = 0.0  // Offset for placing the control point outside the shape
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        self.backgroundColor = .red
        self.layer.cornerRadius = self.frame.width / 2
        self.layer.borderColor = UIColor.white.cgColor
        self.layer.borderWidth = 1.0
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        self.addGestureRecognizer(panGesture)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self.superview)
        
        var newCenter = self.center
        
        if isConstrainedToVertical && isConstrainedToHorizontal {
            // No movement
        } else if isConstrainedToVertical {
            newCenter.y += translation.y
        } else if isConstrainedToHorizontal {
            newCenter.x += translation.x
        } else {
            newCenter.x += translation.x
            newCenter.y += translation.y
        }
        
        self.center = newCenter
        gesture.setTranslation(.zero, in: self.superview)
        
        onMoved?(self.center)
    }
}

class GridBackgroundView: UIView {
    
    var spacing: CGFloat = 50.0
    var showCenterline: Bool = false
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.setStrokeColor(UIColor.gray.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        
        let width = self.bounds.width
        let height = self.bounds.height
        
        for i in stride(from: spacing, to: width, by: spacing) {
            context.move(to: CGPoint(x: i, y: 0))
            context.addLine(to: CGPoint(x: i, y: height))
        }
        
        for i in stride(from: spacing, to: height, by: spacing) {
            context.move(to: CGPoint(x: 0, y: i))
            context.addLine(to: CGPoint(x: width, y: i))
        }
        
        context.strokePath()
        
        if showCenterline {
            context.setStrokeColor(UIColor.red.withAlphaComponent(0.5).cgColor)
            context.setLineDash(phase: 0, lengths: [5, 5])
            let centerY = rect.height / 2
            context.move(to: CGPoint(x: 0, y: centerY))
            context.addLine(to: CGPoint(x: rect.width, y: centerY))
            context.strokePath()
        }
    }
}
