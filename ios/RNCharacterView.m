//
//  RNCharacterView.m
//  RNCharacterView
//

#import "RNCharacterView.h"

#import "PocketSVG.h"

@interface RNCharacterView()
@property NSString *character;
@property BOOL *isAnimating;
@property BOOL *cancelAnimation; // kind of hacky
@end


@implementation RNCharacterView

- (void)setCharacter:(NSString *)character
{
    _character = character;
    self.cancelAnimation = true;
    self.isAnimating = false;
    self.layer.sublayers = nil;
    NSArray *strokeLayers = [self generateStrokeLayers];
    // hack to get around nil view bounds bug
    if (self.bounds.size.width == 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setCharacter:character];
        });
    }
    else {
        for (CAShapeLayer *stroke in strokeLayers) {
            [self.layer addSublayer:stroke];
        }
    }
}

- (NSArray *)generateStrokeLayers
{
    NSString *graphicsPath = [[NSBundle mainBundle] pathForResource:self.character ofType:@"txt"];
    NSError *error;
    NSString *graphicsString = [[NSString alloc] initWithContentsOfFile:graphicsPath
                                                              encoding:NSUTF8StringEncoding
                                                                 error:&error];
    if (error)
        NSLog(@"Error reading graphics file: %@", error.localizedDescription);
    
    NSData *graphicsData = [graphicsString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *graphics = [NSJSONSerialization JSONObjectWithData:graphicsData options:kNilOptions error:&error];
    NSArray *strokeOutlines = graphics[@"strokes"];
    NSArray *strokeMedians = graphics[@"medians"];
    
    if (!strokeOutlines | !strokeMedians) {
        NSLog(@"Error: graphics data not found for stroke");
        return nil;
    }
    
    NSMutableArray *strokes = [@[] mutableCopy];
    
    [strokeMedians enumerateObjectsUsingBlock:^(NSArray *medianPoints, NSUInteger index, BOOL *stop)
     {
         // Create outline layer to mask median path
         CAShapeLayer *outlineLayer = [CAShapeLayer layer];
         CGPathRef outlinePath = [PocketSVG pathFromDAttribute:strokeOutlines[index]];
         outlineLayer.path = outlinePath;
         
         // Create median path masked by stroke outline
         UIBezierPath *medianPath = [UIBezierPath bezierPath];
         [medianPoints enumerateObjectsUsingBlock:^(NSArray *medianPoint, NSUInteger index2, BOOL *stop) {
             NSNumber *x = medianPoint[0];
             NSNumber *y = medianPoint[1];
             CGPoint point = CGPointMake(x.floatValue, y.floatValue);
             ([medianPath isEmpty]) ? [medianPath moveToPoint:point] : [medianPath addLineToPoint:point];
         }];
         
         // Mask stroked median with outline
         CAShapeLayer *stroke = [CAShapeLayer layer];
         stroke.path = medianPath.CGPath;
         stroke.mask = outlineLayer;
         stroke.strokeColor = [[UIColor colorWithRed:0.05f green:0.05f blue:0.05f alpha:1] CGColor];
         stroke.lineWidth = 150; // detect small strokes and set this smaller
         stroke.lineCap = kCALineCapRound;
         stroke.lineJoin = kCALineJoinRound;
         stroke.fillColor = [[UIColor clearColor] CGColor];
         
         // SVGs are upside down and offset vertically 124px
         CGFloat displayToSvgRatio = MIN(self.bounds.size.height, self.bounds.size.width)/1024;
         CGAffineTransform scaleAndFlip = CGAffineTransformMakeScale(displayToSvgRatio, -displayToSvgRatio);
         CGFloat xPadding = (self.bounds.size.width-self.bounds.size.height)/2;
#warning - gotta add y padding if view is taller than wide
         if (xPadding < 0)
             xPadding = 0;
         CGFloat translateDownAndFixOffset = self.bounds.size.height-(124*displayToSvgRatio);
         CGAffineTransform center = CGAffineTransformMakeTranslation(xPadding, translateDownAndFixOffset);
         stroke.affineTransform = CGAffineTransformConcat(scaleAndFlip, center);
         [strokes addObject:stroke];
     }];
    
    return [strokes copy];
}

- (void)animateStrokes
{
    if (self.isAnimating)
        return;
    
    self.isAnimating = true;
    self.cancelAnimation = false; //hack
    NSString *graphicsPath = [[NSBundle mainBundle]pathForResource:self.character ofType:@"txt"];
    NSError *error;
    NSString *graphicsString = [[NSString alloc]initWithContentsOfFile:graphicsPath encoding:NSUTF8StringEncoding error:&error];
    
    if (error)
        NSLog(@"Error reading graphics file: %@", error.localizedDescription);
    
    NSData *graphicsData = [graphicsString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *graphics = [NSJSONSerialization JSONObjectWithData:graphicsData options:kNilOptions error:&error];
    
    if (graphics[@"strokes"] && graphics[@"medians"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self animateStrokes:graphics[@"strokes"] andMedians:graphics[@"medians"]];
        });
    }
    else
        NSLog(@"Error: graphics data not found for stroke");
}


- (void)animateStrokes:(NSArray *)strokeOutlines andMedians:(NSArray *)strokeMedians
{
    self.layer.sublayers = nil;

    NSMutableArray *strokes = [@[] mutableCopy];
    
    [strokeMedians enumerateObjectsUsingBlock:^(NSArray *medianPoints, NSUInteger index, BOOL *stop)
     {
         // Create outline layer to mask median path
         CAShapeLayer *outlineLayer = [CAShapeLayer layer];
         CGPathRef outlinePath = [PocketSVG pathFromDAttribute:strokeOutlines[index]];
         outlineLayer.path = outlinePath;
         
         // Create median path masked by stroke outline
         UIBezierPath *medianPath = [UIBezierPath bezierPath];
         [medianPoints enumerateObjectsUsingBlock:^(NSArray *medianPoint, NSUInteger index2, BOOL *stop) {
             NSNumber *x = medianPoint[0];
             NSNumber *y = medianPoint[1];
             CGPoint point = CGPointMake(x.floatValue, y.floatValue);
             ([medianPath isEmpty]) ? [medianPath moveToPoint:point] : [medianPath addLineToPoint:point];
         }];
         
         // Mask stroked median with outline
         CAShapeLayer *stroke = [CAShapeLayer layer];
         stroke.path = medianPath.CGPath;
         stroke.mask = outlineLayer;
         stroke.strokeColor = [[UIColor colorWithRed:0.05f green:0.05f blue:0.05f alpha:1] CGColor];
         stroke.lineWidth = 150; // detect small strokes and set this smaller
         stroke.lineCap = kCALineCapRound;
         stroke.lineJoin = kCALineJoinRound;
         stroke.fillColor = [[UIColor clearColor] CGColor];
         
         // SVGs are upside down and offset vertically 124px
         CGFloat displayToSvgRatio = MIN(self.bounds.size.height, self.bounds.size.width)/1024;
         CGAffineTransform scaleAndFlip = CGAffineTransformMakeScale(displayToSvgRatio, -displayToSvgRatio);
         CGFloat xPadding = (self.bounds.size.width-self.bounds.size.height)/2;
#warning - gotta add y padding if view is taller than wide
         if (xPadding < 0)
             xPadding = 0;
         CGFloat translateDownAndFixOffset = self.bounds.size.height-(124*displayToSvgRatio);
         CGAffineTransform center = CGAffineTransformMakeTranslation(xPadding, translateDownAndFixOffset);
         stroke.affineTransform = CGAffineTransformConcat(scaleAndFlip, center);
         [strokes addObject:stroke];
         
     }];
    
    [self animateStrokes:strokes withDelay:0.5f fromIndex:0];
}

- (void)animateStrokes:(NSArray *)strokes withDelay:(CGFloat)delay fromIndex:(int)index
{
    [self animateStroke:strokes[index]];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (index == strokes.count-1)
            self.isAnimating = false;
        if (index < strokes.count-1 && !self.cancelAnimation)
            [self animateStrokes:strokes withDelay:delay fromIndex:index+1];
    });
}

- (void)animateStroke:(CAShapeLayer *)stroke
{
    stroke.strokeStart = 0;
    [self.layer addSublayer:stroke];
    CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
#warning - magic number
    pathAnimation.duration = 0.35f;
    pathAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
    pathAnimation.toValue = [NSNumber numberWithFloat:1.0f];
    pathAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    [stroke addAnimation:pathAnimation forKey:@"strokeEndAnimation"];
}


@end
