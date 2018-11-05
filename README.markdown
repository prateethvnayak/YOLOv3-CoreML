# ------UNDER CONSTRUCTION------


# YOLOv3 with Core ML (for Static Image Application)

This repo was forked and modified from  https://github.com/Ma-Dan/YOLOv3-CoreML
The changes made:

1. Application for Static Images (instead of real-time video)

--forked README--
## About YOLO object detection

YOLO is an object detection network. It can detect multiple objects in an image and puts bounding boxes around these objects. [Read hollance's blog post about YOLO](http://machinethink.net/blog/object-detection-with-yolo/) to learn more about how it works.

![YOLO in action](YOLO.jpg)

In this repo you'll find:

- **YOLOv3-CoreML:** A demo app that runs the YOLOv3 neural network on Core ML.
- **Converter:** The scripts needed to convert the original Keras YOLOv3 model to Core ML.

To run the app:

1. Extract YOLOv3 CoreML model in YOLOv3 CoreML model folder and copy to YOLOv3-CoreML/YOLOv3-CoreML folder.
2. Open the **xcodeproj** file in Xcode 9 and run it on a device with iOS 11 or better installed.

The reported "elapsed" time is how long it takes the YOLO neural net to process a single image. The FPS is the actual throughput achieved by the app.

> **NOTE:** Running these kinds of neural networks eats up a lot of battery power. The app can put a limit on the number of times per second it runs the neural net. You can change this in `setUpCamera()` by changing the line `videoCapture.fps = 50` to a smaller number.

## Converting the models

> **NOTE:** You don't need to convert the models yourself. Everything you need to run the demo apps is included in the Xcode projects already. 

The model is converted from Keras h5 model, follow the Quick Start guide [keras-yolo3](https://github.com/qqwweee/keras-yolo3) to get YOLOv3 Keras h5 model, then use coreml.py to convert h5 model to CoreML model.

