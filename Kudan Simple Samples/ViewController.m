#import "ViewController.h"

typedef NS_ENUM(NSInteger, ArbiTrackState) {
    ARBI_STOPPED,
    ARBI_PLACEMENT,
    ARBI_TRACKING,
};

@interface ViewController ()
{
    ArbiTrackState _arbiButtonState;
    float _lastScale;
    ARModelNode *_kudanNode;
}
@end

@implementation ViewController


- (void)setupTracker
{
    ARImageTrackerManager *trackerManager = [ARImageTrackerManager getInstance];
    
    // Initialise the image tracker.
    [trackerManager initialise];
    
    // Load trackable set, which can contain multiple markers.
    ARImageTrackableSet *trackableSet = [[ARImageTrackableSet alloc] initWithBundledFile:@"demo.KARMarker"];
    
    // Add the set of trackables to the tracker.
    [trackerManager addTrackableSet:trackableSet];
    
    // Create a trackable from a bundled file. Give it a unique name which we can use to locate it later.
    ARImageTrackable *wavesTrackable = [[ARImageTrackable alloc] initWithImage:[UIImage imageNamed:@"waves.png"] name:@"waves"];
    
    // Add this new trackable to the tracker.
    [trackerManager addTrackable:wavesTrackable];
}


// Bone and morph animated 3D plane using the real camera image as a texture. Use with Lego marker.
- (void)setupPlane
{
    // The marker we'll be adding to.
    ARImageTrackerManager *trackerManager = [ARImageTrackerManager getInstance];
    ARImageTrackable *legoTrackable = [trackerManager findTrackableByName:@"lego"];
    
    // Import the model.
    ARModelImporter *importer = [[ARModelImporter alloc] initWithBundled:@"plane.armodel"];
    
    // Get a node representing the model's contents.
    ARModelNode *planeNode = [importer getNode];
    
    // Set up camera texture extractor to convert the marker to a usable texture. Texture dimensions can be arbitrary and need not match the aspect ratio of the source.
    ARExtractedCameraTexture *extracted = [[ARExtractedCameraTexture alloc] initWithWidth:512 height:512];
    
    // The marker is the region of interest. width x height in srcNode's coordinate space.
    extracted.srcWidth = legoTrackable.width;
    extracted.srcHeight = legoTrackable.height;
    
    // Create the source node and add it to the marker. Position such that srcWidth x srcWidth in srcNode's space cooresponds to the dimensions of the region of interest.
    extracted.srcNode = [ARNode nodeWithName:@"plane source node"];
    [legoTrackable.world addChild:extracted.srcNode];
    
    // Create a textured material using the extracted texture.
    ARTextureMaterial *cameraMaterial = [[ARTextureMaterial alloc] initWithTexture:extracted.texture];
    
    // Assign cameraMaterial to every mesh in the model.
    for (ARMeshNode *meshNode in planeNode.meshNodes) {
        meshNode.material = cameraMaterial;
    }
    
    // Material that remains on the marker should be black.
    ARMeshNode *blackNode = [planeNode findMeshNode:@"occlusion"];
    blackNode.material = [[ARColourMaterial alloc] initWithRed:0 green:0 blue:0];
    
    // The height of the plane in object space is 22.652, scale it to match the height of the marker.
    float scaleFactor = legoTrackable.height / 22.652;
    [planeNode scaleByUniform:scaleFactor];
    
    // Plane is modelled with y-axis up. Marker has z-axis up. Rotate around the x-axis to correct this.
    [planeNode rotateByDegrees:90 axisX:1 y:0 z:0];
    
    // Add the model to a marker.
    [legoTrackable.world addChild:planeNode];
    
    // Play the animation.
    [planeNode start];
    
    // Loop infinitely.
    planeNode.shouldLoop = YES;
}


// Video on marker demo. Uses the waves marker.
- (void)setupVideo
{
    // The marker we'll be adding to.
    ARImageTrackerManager *trackerManager = [ARImageTrackerManager getInstance];
    ARImageTrackable *wavesTrackable = [trackerManager findTrackableByName:@"waves"];
    
    // Create a video node associated with a video file.
    ARVideoNode *videoNode = [[ARVideoNode alloc] initWithBundledFile:@"waves.mp4"];
    
    // Add it to the marker.
    [wavesTrackable.world addChild:videoNode];
    
    // Scale to fit the width of the marker.
    float scaleFactor = (float)wavesTrackable.width / videoNode.videoTexture.width;
    [videoNode scaleByUniform:scaleFactor];
    
    // Play the video.
    [videoNode play];
    
    // Fade the video in over 1 second.
    videoNode.videoTextureMaterial.fadeInTime = 1;
    
    // Reset the video if it hasn't been played for over two seconds.
    videoNode.videoTexture.resetThreshold = 2;
    
    // Register for touch events.
    [videoNode addTouchTarget:self withAction:@selector(videoWasTouched:)];
}

- (void)videoWasTouched:(ARVideoNode *)videoNode
{
    // Reset the video when touched.
    [videoNode reset];
    [videoNode play];
}

- (void)setupArbiTrack
{
    // Initialise gyro placement. Gyro placement positions content on a virtual floor plane where the device is aiming.
    ARGyroPlaceManager *gyroPlaceManager = [ARGyroPlaceManager getInstance];
    [gyroPlaceManager initialise];
    
    // Import the model.
    ARModelImporter *importer = [[ARModelImporter alloc] initWithBundled:@"kudan.armodel"];
    
    // Get a node representing the model's contents.
    ARModelNode *kudanNode = [importer getNode];
    
    // Start the animation and loop infinitely.
    [kudanNode start];
    kudanNode.shouldLoop = YES;
    
    ARTextureCube *environmentTexture = [[ARTextureCube alloc] initWithBundledFiles:@[ @"chrome_b.png", @"chrome_f.png", @"chrome_u.png", @"chrome_d.png", @"chrome_r.png", @"chrome_l.png"]];
    
    ARLightMaterial *chromeMaterial = [[ARLightMaterial alloc] init];
    chromeMaterial.reflection.reflectivity = 1;
    chromeMaterial.reflection.environment = environmentTexture;
    
    for (ARMeshNode *meshNode in kudanNode.meshNodes) {
        meshNode.material = chromeMaterial;
    }
    
    // Create a material that can occlude with real world objects. Apply it to the ground plane .
    AROcclusionMaterial *occlusionMaterial = [[AROcclusionMaterial alloc] init];
    ARMeshNode *occlusionMeshNode = [kudanNode findMeshNode:@"occlusion"];
    occlusionMeshNode.material = occlusionMaterial;
    
    // Create the node that will be positioned on the floor using the gyro. This will seed the tracking.
    ARNode *targetNode = [ARNode nodeWithName:@"targetNode"];
    [gyroPlaceManager.world addChild:targetNode];
    
    // What to show as the target.
    ARImageNode *targetImageNode = [[ARImageNode alloc] initWithImage:[UIImage imageNamed:@"target.png"]];
    [targetImageNode scaleByUniform:0.1];
    
    // Rotate it so it's parallel to the floor.
    [targetImageNode rotateByDegrees:90 axisX:1 y:0 z:0];
    [targetNode addChild:targetImageNode];
    
    // Initialise the arbitrary tracker.
    ARArbiTrackerManager *arbiTrack = [ARArbiTrackerManager getInstance];
    [arbiTrack initialise];
    
    // Specify which node shall be used as a starting point when the tracker is started.
    arbiTrack.targetNode = targetNode;
    
    // Hide by default.
    arbiTrack.targetNode.visible = NO;
    
    // Add the model to the tracker controlled world node.
    [arbiTrack.world addChild:kudanNode];
    
    _kudanNode = kudanNode;
    
    // Add a pinch gesture to the view to handle scaling.
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(arbiPinch:)];
    [self.cameraView addGestureRecognizer:pinchGesture];
}

- (void)setupContent
{
    // Tracker.
    [self setupTracker];

    // Content.
    [self setupPlane];
    [self setupVideo];
    [self setupArbiTrack];
}

- (IBAction)arbiTrackButtonClicked:(id)sender
{
    ARArbiTrackerManager *arbiTrack = [ARArbiTrackerManager getInstance];
    
    if (_arbiButtonState == ARBI_STOPPED) {
        // Show the target node.
        arbiTrack.targetNode.visible = YES;
        
        _arbiButtonState = ARBI_PLACEMENT;
        [_arbiTrackButton setTitle:@"Start" forState:UIControlStateNormal];
        
        // Stop the image tracker for performance reasons.
        ARImageTrackerManager *trackerManager = [ARImageTrackerManager getInstance];
        [trackerManager stop];
        return;
    }
    
    if (_arbiButtonState == ARBI_PLACEMENT) {
        // Start tracking using the targetNode's current pose as the starting point.
        [arbiTrack start];
        
        // Hide the target node.
        arbiTrack.targetNode.visible = NO;
        
        // Reset the scale.
        _kudanNode.scale = [ARVector3 vectorWithValuesX:1 y:1 z:1];
        
        _arbiButtonState = ARBI_TRACKING;
        [_arbiTrackButton setTitle:@"Stop" forState:UIControlStateNormal];
        return;
    }
    
    if (_arbiButtonState == ARBI_TRACKING) {
        [arbiTrack stop];
        
        _arbiButtonState = ARBI_STOPPED;
        [_arbiTrackButton setTitle:@"ArbiTrack" forState:UIControlStateNormal];
        
        // Start the image tracker again.
        ARImageTrackerManager *trackerManager = [ARImageTrackerManager getInstance];
        [trackerManager start	];
        
        return;
    }
}

- (void)arbiPinch:(UIPinchGestureRecognizer *)gesture
{
    float scaleFactor = gesture.scale;
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _lastScale = 1;
    }
    
    scaleFactor = 1 - (_lastScale - scaleFactor);
    
    
    _lastScale = gesture.scale;
    
    // Scale the node.
    @synchronized ([ARRenderer getInstance]) {
        // The renderer doesn't run on the UI thread so synchronise to prevent updating the transformation mid-draw.
        [_kudanNode scaleByUniform:scaleFactor];
    }
}

@end
