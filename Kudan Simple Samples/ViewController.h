#import <UIKit/UIKit.h>
#import <KudanAR/KudanAR.h>

@interface ViewController : ARCameraViewController

- (IBAction)arbiTrackButtonClicked:(id)sender;
@property (weak) IBOutlet UIButton *arbiTrackButton;

@end

