//
//  RNCharacterView.m
//  RNCharacterView
//

#import "RNCharacterView.h"

#import "PocketSVG.h"

@interface RNCharacterView()
@property (nonatomic) NSString *character;
@property BOOL *quiz;
@property BOOL *isAnimating;
@property BOOL *cancelAnimation; // kind of hacky
@property int totalMistakes;
@end


@implementation RNCharacterView
{
    // Internal
    CAShapeLayer *_layer;
    UIBezierPath *_path;
    CGPoint _points[5];
    uint _counter;
    
    
    // Handwriting
    NSMutableArray *_strokePoints;
    uint _strokeAttempts;
    
    
    // Strokes
    NSArray *_strokeMedians;
    NSArray *_strokeOutlines;
    
    NSArray *_outlineLayers;
    NSArray *_strokeLayers;
    uint _currentStroke;
    
    // Configuration settings
    UIColor *_fillColor;
    UIColor *_strokeColor;
}

- (instancetype)init
{
    self = [super init];
    self.clipsToBounds = YES;
    self.multipleTouchEnabled = NO;
    
    _path = [[UIBezierPath alloc] init];
    _path.lineWidth = 12;
    _path.lineCapStyle = kCGLineCapRound;
    _path.lineJoinStyle = kCGLineJoinRound;
    
    
    _strokePoints = [[NSMutableArray alloc] init];
    _strokeAttempts = 0;
    
    _currentStroke = 0;
    
    _layer = [CAShapeLayer layer];
    _layer.strokeColor = [[UIColor colorWithWhite:0.15f alpha:1] CGColor];
    _layer.lineWidth = 12;
    _layer.lineCap = kCALineCapRound;
    _layer.fillColor = [[UIColor clearColor] CGColor];
    
    return self;
}

- (void)setCharacter:(NSString *)character
{
    _character = character;
    _currentStroke = 0;
    _strokeAttempts = 0;
    _totalMistakes = 0;
    self.cancelAnimation = true;
    self.isAnimating = false;
    self.layer.sublayers = nil;
    [self loadGraphics];
    _outlineLayers = [self generateStrokeLayers];
    _strokeLayers = [self generateStrokeLayers];
    
    // hack to get around nil view bounds bug
    if (self.bounds.size.width == 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setCharacter:character];
        });
    }
    else {
        // if show outline
        if (!self.quiz) {
            for (int i = [_outlineLayers count]-1; i>=0; i--) {
                CAShapeLayer *outline = _outlineLayers[i];
                [self.layer addSublayer:outline];
            }
        }
    }
}


- (void)loadGraphics
{
    NSString *path = [[NSBundle mainBundle] pathForResource:self.character ofType:@"txt"];
    NSError *error;
    NSString *graphicsString = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error) return;
    
    NSData *graphicsData = [graphicsString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *graphics = [NSJSONSerialization JSONObjectWithData:graphicsData options:kNilOptions error:&error];
    if (error) return;
    
    NSMutableArray *medians = [@[] mutableCopy];
    for (NSArray *stroke in graphics[@"medians"]) {
        NSMutableArray *strokeMedians = [@[] mutableCopy];
        for (NSArray *medianPoint in stroke) {
            NSNumber *x = medianPoint[0];
            NSNumber *y = medianPoint[1];
            [strokeMedians addObject:[NSValue valueWithCGPoint:CGPointMake(x.floatValue, y.floatValue)]];
        }
        [medians addObject:strokeMedians];
    }
    
    _strokeOutlines = graphics[@"strokes"];
    _strokeMedians = [medians copy];
}

- (NSArray <CAShapeLayer *> *)generateStrokeLayers
{
    NSMutableArray *strokes = [@[] mutableCopy];
    
    [_strokeMedians enumerateObjectsUsingBlock:^(NSArray *medianPoints, NSUInteger index, BOOL *stop)
     {
         // Create outline layer to mask median path
         CAShapeLayer *outlineLayer = [CAShapeLayer layer];
         CGPathRef outlinePath = [PocketSVG pathFromDAttribute:_strokeOutlines[index]];
         outlineLayer.path = outlinePath;
         outlineLayer.lineWidth = 20;
         
         // Create median path masked by stroke outline
         UIBezierPath *medianPath = [UIBezierPath bezierPath];
         [medianPoints enumerateObjectsUsingBlock:^(NSValue *medianPoint, NSUInteger index2, BOOL *stop) {
             CGPoint point = [medianPoint CGPointValue];
             ([medianPath isEmpty]) ? [medianPath moveToPoint:point] : [medianPath addLineToPoint:point];
         }];
         
         // Mask stroked median with outline
         CAShapeLayer *stroke = [CAShapeLayer layer];
         stroke.path = medianPath.CGPath;
         stroke.mask = outlineLayer;
         stroke.strokeColor = [[UIColor colorWithWhite:0.88f alpha:1] CGColor];
         stroke.lineWidth = 150; // detect small strokes and set this smaller
         stroke.lineCap = kCALineCapRound;
         stroke.lineJoin = kCALineJoinRound;
         stroke.fillColor = [[UIColor clearColor] CGColor];
         
         // SVGs are upside down and offset vertically 124px
         CGFloat displayToSvgRatio = MIN(self.bounds.size.height, self.bounds.size.width)/1024;
         CGAffineTransform scaleAndFlip = CGAffineTransformMakeScale(displayToSvgRatio, -displayToSvgRatio);
         CGFloat translateDownAndFixOffset = self.bounds.size.height-(124*displayToSvgRatio);
         CGAffineTransform center = CGAffineTransformMakeTranslation(0, translateDownAndFixOffset);
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
    
    if (_currentStroke == 0 || _currentStroke == [_strokeLayers count]-1)
        for (CAShapeLayer *stroke in _strokeLayers) {
            [stroke removeFromSuperlayer];
        }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self animateStrokes:_strokeLayers withDelay:0.5f fromIndex:_currentStroke];
    });
}

- (void)animateStrokes:(NSArray *)strokes withDelay:(CGFloat)delay fromIndex:(int)index
{
    [self animateStroke:strokes[index]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (index == strokes.count-1) {
            self.isAnimating = false;
            _currentStroke = 0;
        }
        if (_strokeLayers != strokes || self.cancelAnimation) {
            return;
        }
        if (index < strokes.count-1) {
            [self animateStrokes:strokes withDelay:delay fromIndex:index+1];
        } else {
            for (CAShapeLayer *stroke in _strokeLayers) {
                [stroke removeFromSuperlayer];
            }
        }
    });
}

- (void)animateStroke:(CAShapeLayer *)stroke
{
    [stroke removeAllAnimations];
    stroke.strokeColor = [[UIColor colorWithWhite:0.15f alpha:1] CGColor];
    stroke.strokeStart = 0;
    [self.layer addSublayer:stroke];
    CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    pathAnimation.duration = 0.5f;
    pathAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
    pathAnimation.toValue = [NSNumber numberWithFloat:1.0f];
    [stroke addAnimation:pathAnimation forKey:@"strokeEndAnimation"];
}

- (void)showHint:(CAShapeLayer *)stroke
{
    [stroke removeAllAnimations];
    stroke.strokeColor = [[UIColor colorWithWhite:0.15f alpha:1] CGColor];
    stroke.strokeStart = 0;
    [self.layer addSublayer:stroke];
    CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    pathAnimation.duration = 0.5f;
    pathAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
    pathAnimation.toValue = [NSNumber numberWithFloat:1.0f];
    [stroke addAnimation:pathAnimation forKey:@"strokeEndAnimation"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        pathAnimation.duration = 0.3f;
        pathAnimation.fromValue = [NSNumber numberWithFloat:1.0f];
        pathAnimation.toValue = [NSNumber numberWithFloat:0.0f];
        pathAnimation.fillMode = kCAFillModeForwards;
        pathAnimation.removedOnCompletion = NO;
        [stroke addAnimation:pathAnimation forKey:@"opacityAnimation"];
    });
}

- (void)showStroke:(CAShapeLayer *)stroke
{
    [stroke removeAllAnimations];
    stroke.strokeColor = [[UIColor colorWithWhite:0.10f alpha:1] CGColor];
    CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pathAnimation.duration = 0.3f;
    pathAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
    pathAnimation.toValue = [NSNumber numberWithFloat:1.0f];
    [stroke addAnimation:pathAnimation forKey:@"opacityAnimation"];
    [self.layer addSublayer:stroke];
}


#pragma mark - Drawing Methods

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (self.isAnimating || _currentStroke >= [_strokeLayers count])
        return;
    
    
    _counter = 0;
    UITouch *touch = [touches anyObject];
    _points[0] = [touch locationInView:self];
    [_layer removeFromSuperlayer];
    [_layer removeAllAnimations];
    
    
    [_strokePoints removeAllObjects];
    [_strokePoints addObject:[NSValue valueWithCGPoint:[touch locationInView:self]]];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (_currentStroke >= [_strokeLayers count])
        return;
    
    _counter++;
    UITouch *touch = [touches anyObject];
    _points[_counter] = [touch locationInView:self];
    
    
    if (_counter == 4) {
        [self drawCurve];
        [_strokePoints addObject:[NSValue valueWithCGPoint:[touch locationInView:self]]];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (_currentStroke >= [_strokeLayers count])
        return;
    
    CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pathAnimation.duration = 0.3f;
    pathAnimation.fromValue = [NSNumber numberWithFloat:1.0f];
    pathAnimation.toValue = [NSNumber numberWithFloat:0.0f];
    pathAnimation.fillMode = kCAFillModeForwards;
    pathAnimation.removedOnCompletion = NO;
    [_layer addAnimation:pathAnimation forKey:@"opacity"];
    
    [_path removeAllPoints];
    _counter = 0;
        
    if (_currentStroke < [_strokeLayers count]) {
        if (![self isCorrectStroke]) {
            _strokeAttempts++;
            _totalMistakes++;
            if (_strokeAttempts >= 3) {
                [self showHint:_strokeLayers[_currentStroke]];
            }
            return;
        } else {
            [self showStroke:_strokeLayers[_currentStroke]];
            _currentStroke++;
            _strokeAttempts = 0;
        }
    }
    
    if (_currentStroke == [_strokeLayers count]) {
        if (_totalMistakes <= 1) {
            for (CAShapeLayer *layer in _strokeLayers) {
                [self animate:layer toColor:[UIColor colorWithRed:0.30 green:0.85 blue:0.39 alpha:1.0]];
            }
        } else {
            for (CAShapeLayer *layer in _strokeLayers) {
                [self animate:layer toColor:[UIColor colorWithRed:1 green:0 blue:0 alpha:1.0]];
            }
        }
        
        if (self.onComplete) {
            self.onComplete(@{ @"totalMistakes": [NSNumber numberWithInt:_totalMistakes] });
        }
        
        if (!self.quiz) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                for (CAShapeLayer *layer in _strokeLayers) {
                    [layer removeFromSuperlayer];
                }
                
                _currentStroke = 0;
                _strokeAttempts = 0;
                _totalMistakes = 0;
            });
            
        }
    }
}

- (BOOL)isCorrectStroke
{
    
    NSArray *strokeMedians = _strokeMedians[_currentStroke];
    
    CGPoint firstPoint = [[_strokePoints firstObject] CGPointValue];
    CGPoint lastPoint = [[_strokePoints lastObject] CGPointValue];
    CGPoint middlePoint = [[_strokePoints objectAtIndex:[_strokePoints count] >> 1] CGPointValue];
    
    CGPoint firstMedian = [[strokeMedians firstObject] CGPointValue];
    CGPoint lastMedian = [[strokeMedians lastObject] CGPointValue];
    CGPoint middleMedian = [[strokeMedians objectAtIndex:[strokeMedians count] >> 1] CGPointValue];
    
    CGFloat displayToSvgRatio = MIN(self.bounds.size.height, self.bounds.size.width)/1024;
    CGAffineTransform scaleAndFlip = CGAffineTransformMakeScale(displayToSvgRatio, -displayToSvgRatio);
    CGFloat translateDownAndFixOffset = self.bounds.size.height-(124*displayToSvgRatio);
    CGAffineTransform center = CGAffineTransformMakeTranslation(0, translateDownAndFixOffset);
    CGAffineTransform centerScaleFlip =CGAffineTransformConcat(scaleAndFlip, center);
    firstMedian = CGPointApplyAffineTransform(firstMedian, centerScaleFlip);
    lastMedian = CGPointApplyAffineTransform(lastMedian, centerScaleFlip);
    middleMedian = CGPointApplyAffineTransform(middleMedian, centerScaleFlip);
    
    
    float xDiff1 = fabsf(firstPoint.x - firstMedian.x);
    float yDiff1 = fabsf(firstPoint.y - firstMedian.y);
    float xDiff2 = fabsf(lastPoint.x - lastMedian.x);
    float yDiff2 = fabsf(lastPoint.y - lastMedian.y);
    float xDiff3 = fabsf(middlePoint.x - middleMedian.x);
    float yDiff3 = fabsf(middlePoint.y - middleMedian.y);
    
    
    float firstDiff = sqrtf(pow(xDiff1, 2)+pow(yDiff1, 2));
    float lastDiff = sqrtf(pow(xDiff2, 2)+pow(yDiff2, 2));
    float middleDiff = sqrtf(pow(xDiff3, 2)+pow(yDiff3, 2));
    
    // adjust these to the view bounds
    if (firstDiff < 80 && lastDiff < 100)// && middleDiff < 80)
        return true;
    
    return false;
}

- (void)animate:(CAShapeLayer *)layer toColor:(UIColor *)color
{
    CABasicAnimation *colorAnimation = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
    colorAnimation.duration = 0.25;
    colorAnimation.fromValue = (__bridge id _Nullable)(layer.strokeColor);
    colorAnimation.toValue = (__bridge id _Nullable)[color CGColor];
    colorAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    colorAnimation.fillMode = kCAFillModeForwards;
    colorAnimation.removedOnCompletion = NO;
    [layer addAnimation:colorAnimation forKey:@"strokeColor"];
}

#pragma mark - Drawing methods


- (void)drawCurve
{
    // Move the endpoint to the middle of the line
    _points[3] = CGPointMake((_points[2].x + _points[4].x) / 2, (_points[2].y + _points[4].y) / 2);
    
    [_path moveToPoint:_points[0]];
    [_path addCurveToPoint:_points[3] controlPoint1:_points[1] controlPoint2:_points[2]];
    
    _layer.path = _path.CGPath;
    [_layer removeFromSuperlayer];
    [self.layer addSublayer:_layer];
    
    // Replace points and get ready to handle the next segment
    _points[0] = _points[3];
    _points[1] = _points[4];
    _counter = 1;
}

#pragma mark - Setters


- (void)setFillColor:(UIColor *)fillColor
{
    _fillColor = fillColor;
}

- (void)setStrokeColor:(UIColor *)strokeColor
{
    _strokeColor = strokeColor;
}

- (void)setStrokeThickness:(NSInteger)strokeThickness
{
    _path.lineWidth = strokeThickness;
}

@end
