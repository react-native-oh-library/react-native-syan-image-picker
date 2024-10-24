/**
 * MIT License
 *
 * Copyright (C) 2024 Huawei Device Co., Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import image from '@ohos.multimedia.image';
import Logger from '../Logger';
import display from '@ohos.display';
import router from '@ohos.router';
import { BusinessError } from '@ohos.base';
import { Rectangle } from '../utils/types';
import { Action, DownPos, DragObj } from '../utils/CropModel';
import { Constants } from '../utils/Constants';
import { getPixelMap } from '../utils/DecodeAndEncodeUtil';
import { RotateType } from '../viewmodel/viewAndModel';
import { encode } from '../utils/EncodeUtil';
import Matrix4 from '@ohos.matrix4'
import fs from '@ohos.file.fs';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common2D, drawing } from '@kit.ArkGraphics2D';

let hotspotsWidth: number = 18;
const PHONE_MIN_CROP: number = 43;
const TAG: string = 'ImageCrop';


@Entry
@Component
export struct ImageCrop {
  @State pm: PixelMap | undefined = undefined;
  @StorageProp('filePath') filePath: string = '';
  @State private model: CropModel = new CropModel();
  @StorageProp('showCropCircle') showCropCircle: boolean = false;
  @StorageProp('circleCropRadius') circleCropRadius: number = display.getDefaultDisplaySync().width * 0.45;
  @StorageProp('CropW') CropW: number = 0;
  @StorageProp('CropH') CropH: number = 0;
  @StorageProp('cropperRotate') cropperRotate: string = '';
  setting: RenderingContextSettings = new RenderingContextSettings(true);
  context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.setting);
  @Provide('isPixelMapChange') @Watch('flushPixelMap') isPixelMapChange: boolean = false;
  @StorageProp('textTitle') title: string = '裁剪';
  @StorageProp('cancelText') cancel: string = '取消';
  @StorageProp('cancelTextColor') cancelTextColor: string = '#ffffff';
  @StorageProp('chooseText') choose: string = '确定';
  @StorageProp('chooseTextColor') chooseTextColor: string = '#ffffff';
  @StorageProp('freeStyleCropEnabled') freeStyleCropEnabled: boolean = false;
  @StorageProp('enableRotationGesture') enableRotationGesture: boolean = false;
  @State uri: string = '';
  @State icon?: image.PixelMap = undefined;
  @State screenWidth: number = px2vp(display.getDefaultDisplaySync().width);
  @State screenHeight: number = px2vp(display.getDefaultDisplaySync().height);
  @State imageWith: number = this.screenWidth * 0.6;
  @State imageHeight: number = this.screenHeight * 0.6;
  DEFAULT_MASK_STYLE: string = 'rgba(0, 0, 0, 0.3)';
  @State clipSize: Rectangle = new Rectangle(0, 0, 0, 0);
  @State maxClipSize: Rectangle = new Rectangle(0, 0, 0, 0);
  @State display: Rectangle = new Rectangle(0, 0, 0, 0);
  @State crop: number = 0;
  @State hasSplitLine: boolean = true;
  @State clipVisible: boolean = true;
  @State imgOffSetX: number = 0;
  @State imgOffSetY: number = 0;
  @State imgScale: number = 1;
  @State currentScale: number = 1;
  @State preOffsetX: number = 0;
  @State preOffsetY: number = 0;
  @State clipRatio: number = 0;
  @State imageFlag: boolean = true;
  @State angle: number = 0;
  @State rotateValue: number = 0;
  private minSize = PHONE_MIN_CROP;
  private dragObj: DragObj = new DragObj(false);
  private clb: number = 1
  @State saveButtonOptions: SaveButtonOptions = {
    text: SaveDescription.SAVE,
    buttonType: ButtonType.Capsule
  }

  pixelInit(path: string) {
    this.angle = 0;
    this.screenWidth = px2vp(display.getDefaultDisplaySync().width);
    this.screenHeight = px2vp(display.getDefaultDisplaySync().height);
    this.uri = path;
    getPixelMap(this.uri)
      .then((pixelMap: image.PixelMap) => {
        if (pixelMap) {
          this.isPixelMapChange = !this.isPixelMapChange;
          this.icon = pixelMap;
          pixelMap.getImageInfo().then((imageInfo) => {
            this.imageHeight = imageInfo.size == undefined ? 0 : imageInfo.size?.height;
            this.imageWith = imageInfo.size == undefined ? 0 : imageInfo.size?.width;
            this.initCropBox(this.imageWith, this.imageHeight, this.screenWidth, this.screenHeight);
          })
        }
      })

    if (this.showCropCircle) {
      this.model.setImage(this.filePath)
      if (!!!this.circleCropRadius) {
        this.circleCropRadius = display.getDefaultDisplaySync().width * 0.45
      }
      this.model.setFrameWidth(this.circleCropRadius * 2)
    } else {
      if (!!!this.CropW) {
        this.CropW = px2vp(display.getDefaultDisplaySync().width) * 0.6;
      }
      if (!!!this.CropH) {
        this.CropH = px2vp(display.getDefaultDisplaySync().width) * 0.6;
      }
    }
  }

  resetImg(): void {
    this.imgScale = 1;
    this.currentScale = 1;
    this.preOffsetX = 0;
    this.preOffsetY = 0;
  }

  initCropBox(imageWidth: number, imageHeight: number, screenWidth: number, screenHeight: number) {
    if (imageHeight / imageWidth < screenHeight / screenWidth) {
      this.clb = imageWidth / (screenWidth - hotspotsWidth * 2);
    } else {
      this.clb = imageHeight / (screenHeight - hotspotsWidth * 2 - 56 * 2);
    }
    let imgHeight = Math.round(imageHeight / this.clb);
    let imgWidth = Math.round(imageWidth / this.clb);

    let left = (screenWidth - imgWidth) / 2;
    let top = (screenHeight - imgHeight) / 2 - 56;
    let right = imgWidth + left;
    let bottom = imgHeight + top;

    this.maxClipSize = new Rectangle(left, top, right, bottom);

    if (this.CropW > 0) {
      left = (screenWidth - this.CropW) / 2;
      right = this.CropW + left;
    }
    if (this.CropH > 0) {
      top = (screenHeight - this.CropH) / 2 - 56;
      bottom = this.CropH + top;
    }

    this.clipSize = new Rectangle(left, top, right, bottom);
    this.display = new Rectangle(0, 0, this.screenWidth, this.screenHeight - 56 * 2);
  }

  aboutToAppear() {
    this.pixelInit(this.filePath);
  }

  aboutToDisappear(): void {
    let arrayData =
      ['filePath', 'textTitle', 'chooseText', 'chooseTextColor', 'cancelText', 'cancelTextColor', 'cropperRotate'];
    this.clearData(arrayData);
  }

  clearData(arrayData: Array<string>) {
    for (let i = 0; i < arrayData.length; i++) {
      AppStorage.setOrCreate(arrayData[i], '');
    }
  }

  @Builder
  CropTitleBar() {
    Text("裁剪")
      .fontColor("#ffffff")
      .fontSize(20)
      .textAlign(TextAlign.Center)
      .width('100%')
      .height(56)
      .position({ x: 0, y: 0 })
      .backgroundColor(Color.Black)
  }

  @Builder
  CropImageArea() {
    Stack() {
      if (this.showCropCircle) {
        CropView({
          model: this.model,
        })
          .layoutWeight(1)
          .width('100%')
      } else {
        Image(this.icon)
          .objectFit(ImageFit.Contain)
          .position({ x: this.imgOffSetX, y: this.imgOffSetY })
          .scale({ x: this.imgScale, y: this.imgScale })
          .padding(hotspotsWidth)
          .width('100%')
          .height('100%')
        Row()
          .height(this.clipSize.height())
          .width(this.clipSize.left - this.display.left)
          .position({ x: this.display.left, y: this.clipSize.top })
          .backgroundColor(this.DEFAULT_MASK_STYLE)

        Row()
          .height(this.clipSize.top - this.display.top)
          .width(this.display.width())
          .position({ x: this.display.left, y: this.display.top })
          .backgroundColor(this.DEFAULT_MASK_STYLE)

        Row()
          .height(this.clipSize.height())
          .width(this.display.right - this.clipSize.right)
          .position({ x: this.clipSize.right, y: this.clipSize.top })
          .backgroundColor(this.DEFAULT_MASK_STYLE)

        Row()
          .height(this.display.bottom - this.clipSize.bottom)
          .width(this.display.width())
          .position({ x: this.display.left, y: this.clipSize.bottom })
          .backgroundColor(this.DEFAULT_MASK_STYLE)

        RectangleSizer({
          clipSize: this.clipSize,
          onDrag: this.onDragStartFun,
          clipVisible: this.clipVisible,
          hasSplitLine: this.hasSplitLine
        })
      }
    }
    .height(this.screenHeight - 56 * 2)
    .width('100%')
    .backgroundColor(Color.Black)
    .onTouch(this.touchHandler)
    .gesture(GestureGroup(GestureMode.Parallel,
      PinchGesture({ fingers: Constants.DOUBLE_NUMBER })
        .onActionStart((event?: GestureEvent) => {
          console.info("image crop PinchGesture onActionStart  --》")
        })
        .onActionUpdate((event?: GestureEvent) => {
          console.info("image crop PinchGesture onActionUpdate  --》")
          if (event) {
            this.imgScale = this.currentScale * event.scale;
          }
        })
        .onActionEnd(() => {
          if (this.imgScale < 1) {
            this.resetImg();
            this.imgOffSetX = 0;
            this.imgOffSetY = 0;
          } else {
            this.currentScale = this.imgScale;
          }
        }),
      PanGesture()
        .onActionStart((event?: GestureEvent) => {
          console.info("image crop  PanGesture onActionStart  --》")
        })
        .onActionStart(() => {
          this.preOffsetX = this.imgOffSetX;
          this.preOffsetY = this.imgOffSetY;
        })
        .onActionUpdate((event?: GestureEvent) => {
          if (event && this.imageFlag) {
            this.imgOffSetX = this.preOffsetX + event.offsetX;
            this.imgOffSetY = this.preOffsetY + event.offsetY;
            Logger.info(TAG, "into flushPixelMapChange x : " + this.imgOffSetX + " y : " + this.imgOffSetY)
          }
        }),
      RotationGesture()
        .onActionEnd((event: GestureEvent) => {
          if (this.enableRotationGesture) {
            this.rotateValue = event.angle;
            const sum = Math.ceil(this.rotateValue / 90);
            this.resetImg();
            this.imgOffSetX = 0;
            this.imgOffSetY = 0;
            if (sum > 0) {
              this.rotateImage(RotateType.CLOCKWISE);
            } else {
              this.rotateImage(RotateType.ANTI_CLOCK);
            }
          }
        })
    ))
  }

  @Builder
  BottomToolbar() {
    Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.End }) {
      Button("取消")
        .buttonStyle(ButtonStyleMode.EMPHASIZED)
        .width(80)
        .margin({ right: 15 })
        .fontColor("#ffffff")
        .backgroundColor(Color.Blue)
        .onClick(async () => {
          this.pixelInit(this.filePath)
          router.back()
        });

      SaveButton(this.saveButtonOptions)
        .onClick(async (event, result: SaveButtonOnClickResult) => {
          if (result == SaveButtonOnClickResult.SUCCESS) {
            if (this.icon) {
              if (this.showCropCircle) {
                let circleResult = await this.model.crop(image.PixelMapFormat.RGBA_8888);
                let imageInfo: image.ImageInfo = circleResult.getImageInfoSync()
                let width = imageInfo.size.width
                let height = imageInfo.size.height
                const buffer: ArrayBuffer = new ArrayBuffer(circleResult.getPixelBytesNumber());
                const opts: image.InitializationOptions = {
                  editable: true,
                  pixelFormat: image.PixelMapFormat.RGBA_8888,
                  size: { height: height, width: width }
                };
                let originalPixelMap = await image.createPixelMap(buffer, opts);
                const canvas = new drawing.Canvas(originalPixelMap)
                let cWidth = canvas.getWidth()
                let cHeight = canvas.getHeight()
                let cRadius=cWidth/2
                const pen = new drawing.Pen();
                pen.setAntiAlias(true)
                pen.setStrokeWidth(10);
                canvas.attachPen(pen);
                canvas.drawColor(255, 245, 252, 255)
                let rect: common2D.Rect = {
                  left: 0,
                  top: 0,
                  right: cWidth,
                  bottom: cHeight
                };
                let path = new drawing.Path();
                path.addCircle(cRadius, cRadius, cRadius, drawing.PathDirection.CLOCKWISE)
                canvas.attachPen(pen);
                canvas.clipPath(path,drawing.ClipOp.INTERSECT,true)
                canvas.drawImageRect(circleResult, rect)
                let imgPath = await encode(this, originalPixelMap);
                try {
                  let context = getContext();
                  let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
                  let assetChangeRequest: photoAccessHelper.MediaAssetChangeRequest =
                    photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(context, imgPath);
                  await phAccessHelper.applyChanges(assetChangeRequest);
                  AppStorage.setOrCreate('cropImagePath', assetChangeRequest.getAsset().uri)
                  AppStorage.setOrCreate('width', imageInfo.size.width)
                  AppStorage.setOrCreate('height', imageInfo.size.height)
                  AppStorage.setOrCreate('size', imageInfo.size.height * imageInfo.size.height)
                  router.back()
                } catch (err) {
                  console.error(`create asset failed with error: ${err.code}, ${err.message}`);
                }
              } else {
                let xOff = this.imageWith * (this.imgScale - 1) / 2;
                let yOff = this.imageHeight * (this.imgScale - 1) / 2;
                let region: image.Region = { x: 0, y: 0, size: { height: this.imageHeight, width: this.imageWith } };
                region.x =
                  (this.clipSize.left - this.maxClipSize.left) / this.imgScale * this.clb + (xOff / this.imgScale) -
                    this.imgOffSetX / this.imgScale * this.clb;
                region.size.width =
                  this.imageWith - region.x - (this.maxClipSize.right - this.clipSize.right) / this.imgScale * this.clb
                    - (xOff / this.imgScale) - this.imgOffSetX / this.imgScale * this.clb;
                region.y =
                  (this.clipSize.top - this.maxClipSize.top) / this.imgScale * this.clb + (yOff / this.imgScale) -
                    this.imgOffSetY / this.imgScale * this.clb;
                region.size.height =
                  this.imageHeight - region.y -
                    (this.maxClipSize.bottom - this.clipSize.bottom) / this.imgScale * this.clb
                    - (yOff / this.imgScale) - this.imgOffSetY / this.imgScale * this.clb;

                this.icon.crop(region, async (err: BusinessError) => {
                  if (err != undefined) {
                    console.error("Failed to crop pixelmap." + JSON.stringify(err));
                    return;
                  } else {
                    if (!!this.icon) {
                      let imgPath = await encode(this, this.icon);
                      let imageInfo = this.icon.getImageInfoSync()
                      try {
                        let context = getContext();
                        let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
                        let assetChangeRequest: photoAccessHelper.MediaAssetChangeRequest =
                          photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(context, imgPath);
                        await phAccessHelper.applyChanges(assetChangeRequest);
                        AppStorage.setOrCreate('cropImagePath', assetChangeRequest.getAsset().uri)
                        AppStorage.setOrCreate('width', imageInfo.size.width)
                        AppStorage.setOrCreate('height', imageInfo.size.height)
                        AppStorage.setOrCreate('size', imageInfo.size.height * imageInfo.size.height)
                        router.back()
                      } catch (err) {
                        console.error(`create asset failed with error: ${err.code}, ${err.message}`);
                      }
                    }
                  }
                })
              }
            }
          } else {
            console.error('SaveButtonOnClickResult create asset failed');
          }
        })
        .width(80)

      Text("")
        .textStyle()
        .margin({ right: 20 })
    }
    .width('100%')
    .height(56)
    .position({ x: 0, y: (this.screenHeight - 56) })
    .backgroundColor(Color.Black)
  }

  rotateImage(rotateType: RotateType) {
    Logger.info(TAG, "into rotateImage rotateType : " + rotateType)
    if (rotateType === RotateType.CLOCKWISE) {
      if (!this.icon) {
        Logger.info(TAG, "into rotateImage return")
        return;
      }
      try {
        this.icon.rotate(Constants.CLOCK_WISE)
          .then(() => {
            this.angle = this.angle + Constants.CLOCK_WISE;
            this.flushPixelMapChange(this.angle);
          })
      } catch (error) {
      }
    }
    if (rotateType === RotateType.ANTI_CLOCK) {
      if (!this.icon) {
        Logger.info(TAG, "into rotateImage return")
        return;
      }
      try {
        this.icon.rotate(Constants.ANTI_CLOCK)
          .then(() => {
            this.angle = this.angle + Constants.ANTI_CLOCK;
            this.flushPixelMapChange(this.angle);
          })
      } catch (error) {
      }
    }
  }

  flushPixelMapChange(angle: number) {
    this.isPixelMapChange = !this.isPixelMapChange;
    let clipAngle = angle / 90;
    switch (Math.abs(clipAngle % 4)) {
      case 0:
      case 2:
        this.initCropBox(this.imageWith, this.imageHeight, this.screenWidth, this.screenHeight);
        break;
      default:
        this.initCropBox(this.imageHeight, this.imageWith, this.screenWidth, this.screenHeight);
        break;
    }
  }

  flushPixelMap() {
    const temp = this.icon;
    this.icon = undefined;
    this.icon = temp;
  }

  onDragStartFun =
    (event: TouchEvent, left: boolean, top: boolean, right: boolean, bottom: boolean, multiCrop: boolean): void => {
      let downPos = new DownPos(this.clipSize.left, this.clipSize.top, this.clipSize.bottom, this.clipSize.right);
      let action = new Action(left, top, right, bottom);
      this.dragObj = new DragObj(true, event.touches[0].screenX, event.touches[0].screenY, action, downPos, multiCrop);
    }

  private endImageDrag(): void {
    let imageWidth = this.imageHeight;
    let imageHeight = this.imageWith;
    if ([0, 2].includes(Math.abs((this.angle / 90) % 4))) {
      imageWidth = this.imageWith;
      imageHeight = this.imageHeight;
    }

    let crop: Rectangle =
      new Rectangle(this.clipSize.left, this.clipSize.top, this.clipSize.right, this.clipSize.bottom);

    let extraLeft = 0;
    let extraTop = 0;
    let extraRight = 0;
    let extraBottom = 0;

    let actualHeight = 0;
    let actualWidth = 0;

    let imgOffSetX = this.imgOffSetX;
    let imgOffSetY = this.imgOffSetY;

    let scaleOffsetX = 0;
    let scaleOffsetY = 0;

    actualHeight = Math.round(imageHeight / this.clb);
    actualWidth = Math.round(imageWidth / this.clb);
    extraLeft = (this.screenWidth - actualWidth) / 2;
    extraTop = (this.screenHeight - actualHeight) / 2 - 56;
    extraRight = actualWidth + extraLeft;
    extraBottom = actualHeight + extraTop;

    scaleOffsetX =
      this.imgScale > 1 ? 0 - ((extraRight - extraLeft) * this.imgScale - (extraRight - extraLeft)) / 2 : 0;
    scaleOffsetY =
      this.imgScale > 1 ? 0 - ((extraBottom - extraTop) * this.imgScale - (extraBottom - extraTop)) / 2 : 0;

    const imageRight = this.imgOffSetX + actualWidth;
    const imageBottom = this.imgOffSetY + actualHeight;

    const cropRight = crop.right
    const cropBottom = crop.bottom;

    if (this.imgOffSetX + scaleOffsetX > crop.left - extraLeft) {
      imgOffSetX = crop.left - extraLeft - scaleOffsetX;
    }

    if (this.imgOffSetY + scaleOffsetY > crop.top - extraTop) {
      imgOffSetY = crop.top - extraTop - scaleOffsetY;
    }

    if (imageRight - scaleOffsetX < cropRight - extraLeft) {
      imgOffSetX = cropRight - extraRight + scaleOffsetX;
    }

    if (imageBottom - scaleOffsetY < cropBottom - extraTop) {
      imgOffSetY = cropBottom - extraBottom + scaleOffsetY;
    }
    this.imgOffSetX = imgOffSetX;
    this.imgOffSetY = imgOffSetY;
  }

  touchHandler: (event: TouchEvent | undefined) => void = (event: TouchEvent | undefined): void => {
    if (!event) {
      return;
    }

    if (event.type === TouchType.Up) {
      this.dragObj.dragging = false;
      this.endImageDrag();
    }

    if (event.type === TouchType.Down) {
      Logger.info(TAG, "Down")
    }

    if (event.type === TouchType.Move) {
      if (!this.dragObj.dragging) {
        this.imageFlag = true;
        return;
      }
      this.imageFlag = false;
      if (this.freeStyleCropEnabled) {
        return;
      }
      let touch = event.touches[0];
      let delX: number = touch.screenX - this.dragObj.x;
      let delY: number = touch.screenY - this.dragObj.y;
      let newPosition = this.clipSize.clone();
      let direction = this.dragObj.action;
      if (this.dragObj.multiCrop) {
        this.getMultiCropRect(delX, delY, newPosition, direction, event.pressure);
      } else {
        this.getSingleCropRect(delX, delY, newPosition, direction, event.pressure);
      }
    }
  }

  getMultiCropRect(delX: number, delY: number, newPosition: Rectangle, direction: Action, pressure: number) {
    if (direction.left) {
      newPosition.left = this.dragObj.downPos.left + delX;
      let width = this.clipSize.right - newPosition.left;
      if (this.clipRatio > 0) {
        let height = width / this.clipRatio;
        if (height <= this.minSize) {
          newPosition.left = this.clipSize.right - this.minSize * this.clipRatio;
        }
      } else if (width <= this.minSize) {
        newPosition.left = this.clipSize.right - this.minSize;
      }
      if (newPosition.left < this.maxClipSize.left) {
        newPosition.left = this.maxClipSize.left;
      }
    }
    if (direction.top) {
      newPosition.top = this.dragObj.downPos.top + delY;
      let height = this.clipSize.bottom - newPosition.top;
      if (this.clipRatio > 0) {
        let width = height * this.clipRatio;
        if (width <= this.minSize) {
          newPosition.top = this.clipSize.bottom - this.minSize / this.clipRatio;
        }
      } else if (height <= this.minSize) {
        newPosition.top = this.clipSize.bottom - this.minSize;
      }
      if (newPosition.top < this.maxClipSize.top) {
        newPosition.top = this.maxClipSize.top;
      }
    }
    if (direction.right) {
      newPosition.right = this.dragObj.downPos.right + delX;
      let width = newPosition.right - this.clipSize.left;
      if (this.clipRatio > 0) {
        let height = width / this.clipRatio;
        if (height <= this.minSize) {
          newPosition.right = this.clipSize.left + this.minSize * this.clipRatio;
        }
      } else if (width <= this.minSize) {
        newPosition.right = this.clipSize.left + this.minSize;
      }
      if (newPosition.right > this.maxClipSize.right) {
        newPosition.right = this.maxClipSize.right;
      }
    }
    if (direction.bottom) {
      newPosition.bottom = this.dragObj.downPos.bottom + delY;
      let height = newPosition.bottom - this.clipSize.top;
      if (this.clipRatio > 0) {
        let width = height * this.clipRatio;
        if (width <= this.minSize) {
          newPosition.bottom = this.clipSize.top + this.minSize / this.clipRatio;
        }
      } else if (height <= this.minSize) {
        newPosition.bottom = this.clipSize.top + this.minSize;
      }
      if (newPosition.bottom > this.maxClipSize.bottom) {
        newPosition.bottom = this.maxClipSize.bottom;
      }
    }
    this.clipSize = new Rectangle(newPosition.left, newPosition.top, newPosition.right, newPosition.bottom);
  }

  getSingleCropRect(delX: number, delY: number, newPosition: Rectangle, direction: Action, pressure: number) {
    if (direction.left) {
      let newX = this.dragObj.downPos.left + delX;
      newX = newX < this.dragObj.downPos.right - this.minSize ? newX : this.dragObj.downPos.right - this.minSize
      if (this.clipRatio > 0) {
        let width = this.clipSize.right - newX;
        let height = width / this.clipRatio;
        newPosition.top = this.clipSize.top - (height - this.clipSize.height()) / 2;
        newPosition.bottom = this.clipSize.bottom + (height - this.clipSize.height()) / 2;
        if (height <= this.minSize) {
          newX = this.clipSize.right - this.minSize * this.clipRatio;
        }
      }
      newPosition.left = newX;
      if (newPosition.left < this.maxClipSize.left) {
        newPosition.left = this.maxClipSize.left;
      }
    } else if (direction.right) {
      let newX = this.dragObj.downPos.right + delX;
      if (newX < this.dragObj.downPos.left + this.minSize) {
        newX = this.dragObj.downPos.left + this.minSize;
      }
      if (this.clipRatio > 0) {
        let width = newX - this.clipSize.left;
        let height = width / this.clipRatio;
        newPosition.top = this.clipSize.top - (height - this.clipSize.height()) / 2;
        newPosition.bottom = this.clipSize.bottom + (height - this.clipSize.height()) / 2;
        if (height <= this.minSize) {
          newX = this.minSize * this.clipRatio + this.clipSize.left;
        }
      }
      newPosition.right = newX;
      if (newPosition.right > this.maxClipSize.right) {
        newPosition.right = this.maxClipSize.right;
      }
    } else if (direction.top) {
      let newY = this.dragObj.downPos.top + delY;
      newY = newY < this.dragObj.downPos.bottom - this.minSize ? newY : this.dragObj.downPos.bottom - this.minSize
      if (this.clipRatio > 0) {
        let height = this.clipSize.bottom - newY;
        let width = height * this.clipRatio;
        newPosition.left = this.clipSize.left - (width - this.clipSize.width()) / 2;
        newPosition.right = this.clipSize.right + (width - this.clipSize.width()) / 2;
        if (width <= this.minSize) {
          newY = this.clipSize.bottom - this.minSize / this.clipRatio;
        }
      }
      newPosition.top = newY;
      if (newPosition.top < this.maxClipSize.top) {
        newPosition.top = this.maxClipSize.top;
      }
    } else if (direction.bottom) {
      let newY = this.dragObj.downPos.bottom + delY;
      if (newY < this.dragObj.downPos.top + this.minSize) {
        newY = this.dragObj.downPos.top + this.minSize;
      }
      if (this.clipRatio > 0) {
        let height = newY - this.clipSize.top;
        let width = height * this.clipRatio;
        newPosition.left = this.clipSize.left - (width - this.clipSize.width()) / 2;
        newPosition.right = this.clipSize.right + (width - this.clipSize.width()) / 2;
        if (width <= this.minSize) {
          newY = this.minSize / this.clipRatio + this.clipSize.top;
        }
      }
      newPosition.bottom = newY;
      if (newPosition.bottom > this.maxClipSize.bottom) {
        newPosition.bottom = this.maxClipSize.bottom;
      }
    }
    this.clipSize = new Rectangle(newPosition.left, newPosition.top, newPosition.right, newPosition.bottom);
  }

  build() {
    Stack() {
      this.CropImageArea();
      this.CropTitleBar();
      this.BottomToolbar();
    }
    .backgroundColor(Color.Black)
    .width('100%')
    .height('100%')
  }
}

export function Event(...args: ESObject): void {
}

@Component
export struct RectangleSizer {
  @Prop clipSize: Rectangle = new Rectangle(0, 0, 0, 0);
  public onDrag: (event: TouchEvent, left: boolean, top: boolean, right: boolean, bottom: boolean,
    multiCrop: boolean) => void = Event
  @Prop clipVisible: boolean = true;
  @State isScrolling: boolean = false;
  @State isTouched: boolean = false;
  @Prop hasSplitLine: boolean = true;
  @StorageProp('showCropFrame') showCropFrame: boolean = true;
  @StorageProp('showCropGuidelines') showCropGuidelines: boolean = true;
  @Prop isScreenPortrait: boolean = false;

  build() {
    Stack() {
      Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.SpaceBetween }) {
        Row().rowStyle().id('petalClip_frostedGlass_top')
        Row().rowStyle2(this.isScrolling).id('petalClip_frostedGlass_row_81_1')
        Row().rowStyle2(this.isScrolling).id('petalClip_frostedGlass_row_81_2')
        Row().rowStyle1(this.hasSplitLine || this.isScrolling).id('petalClip_frostedGlass_row_9_1')
        Row().rowStyle2(this.isScrolling).id('petalClip_frostedGlass_row_81_3')
        Row().rowStyle2(this.isScrolling).id('petalClip_frostedGlass_row_81_4')
        Row().rowStyle1(this.hasSplitLine || this.isScrolling).id('petalClip_frostedGlass_row_9_2')
        Row().rowStyle2(this.isScrolling).id('petalClip_frostedGlass_row_81_5')
        Row().rowStyle2(this.isScrolling).id('petalClip_frostedGlass_row_81_6')
        Row().rowStyle().id('petalClip_frostedGlass_bottom')
      }
      .visibility(this.showCropGuidelines ? Visibility.Visible : Visibility.Hidden)
      .padding(hotspotsWidth)

      Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.SpaceBetween }) {
        Column().columnStyle().id('petalClip_frostedGlass_left')
        Column().columnStyle2(this.isScrolling).id('petalClip_frostedGlass_column_81_1')
        Column().columnStyle2(this.isScrolling).id('petalClip_frostedGlass_column_81_2')
        Column()
          .columnStyle1(this.hasSplitLine || this.isScrolling)
          .id('petalClip_frostedGlass_column_9_1')
        Column().columnStyle2(this.isScrolling).id('petalClip_frostedGlass_column_81_3')
        Column().columnStyle2(this.isScrolling).id('petalClip_frostedGlass_column_81_4')
        Column()
          .columnStyle1(this.hasSplitLine || this.isScrolling)
          .id('petalClip_frostedGlass_column_9_2')
        Column().columnStyle2(this.isScrolling).id('petalClip_frostedGlass_column_81_5')
        Column().columnStyle2(this.isScrolling).id('petalClip_frostedGlass_column_81_6')
        Column().columnStyle().id('petalClip_frostedGlass_right')
      }
      .visibility(this.showCropGuidelines ? Visibility.Visible : Visibility.Hidden)
      .padding(hotspotsWidth)

      Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.SpaceBetween }) {
        Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.SpaceBetween }) {
          Row()
            .width(20)
            .height(20)
            .border({ width: { top: 3, left: 3 }, color: { top: '#FFFFFF', left: '#FFFFFF' } })
            .id('petalClip_frostedGlass_rect_leftTop')
          Row()
            .width(20)
            .height(20)
            .border({ width: { top: 3 }, color: { top: '#FFFFFF' } })
            .id('petalClip_frostedGlass_rect_topMiddle')
          Row()
            .width(20)
            .height(20)
            .border({ width: { top: 3, right: 3 }, color: { top: '#FFFFFF', right: '#FFFFFF' } })
            .id('petalClip_frostedGlass_rect_rightTop')
        }
        .height(Math.min(20, this.clipSize.height() / 3 + 4)).clip(true)

        Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.SpaceBetween }) {
          Row()
            .width(20)
            .height(20)
            .border({ width: { left: 3 }, color: { left: '#FFFFFF' } })
            .id('petalClip_frostedGlass_rect_leftMiddle')
          Row()
            .width(20)
            .height(20)
            .border({ width: { right: 3 }, color: { right: '#FFFFFF' } })
            .id('petalClip_frostedGlass_rect_rightMiddle')
        }
        .height(Math.min(20, this.clipSize.height() / 3 + 1)).clip(true)

        Flex({ direction: FlexDirection.Row, justifyContent: FlexAlign.SpaceBetween }) {
          Row()
            .width(20)
            .height(Math.min(20, this.clipSize.height() / 3 + 4))
            .border({ width: { bottom: 3, left: 3 }, color: { bottom: '#FFFFFF', left: '#FFFFFF' } })
            .id('petalClip_frostedGlass_rect_leftBottom')
          Row()
            .width(20)
            .height(Math.min(20, this.clipSize.height() / 3 + 4))
            .border({ width: { bottom: 3 }, color: { bottom: '#FFFFFF' } })
            .id('petalClip_frostedGlass_rect_MiddleBottom')
          Row()
            .width(20)
            .height(Math.min(20, this.clipSize.height() / 3 + 4))
            .border({ width: { bottom: 3, right: 3 }, color: { bottom: '#FFFFFF', right: '#FFFFFF' } })
            .id('petalClip_frostedGlass_rect_rightBottom')
        }
      }
      .visibility(this.showCropFrame ? Visibility.Visible : Visibility.Hidden)
      .padding(12)
    }
    .width(this.clipSize.width() + hotspotsWidth * 2)
    .height(this.clipSize.height() + hotspotsWidth * 2)
    .visibility(this.clipVisible ? Visibility.Visible : Visibility.Hidden)
    .position({
      x: this.clipSize.left - hotspotsWidth,
      y: this.clipSize.top - hotspotsWidth,
    })
    .onTouch((event?: TouchEvent) => {
      if (!event) {
        return;
      }
      if (this.isScrolling) {
        return;
      }
      if (event.touches.length >= 2) {
        return;
      }
      let touch = event.touches[0];
      let eventX = touch.x;
      let eventY = touch.y;
      if (event.type == TouchType.Down) {
        if (this.isTouched) {
          return;
        }
        this.isTouched = true;
        let eventLeft = eventX < (2 * hotspotsWidth);
        let eventTop = eventY < (2 * hotspotsWidth);
        let eventRight = eventX > this.clipSize.width();
        let eventBottom = eventY > this.clipSize.height();

        let eventCount = (eventLeft ? 1 : 0) + (eventTop ? 1 : 0) + (eventRight ? 1 : 0) + (eventBottom ? 1 : 0);
        if (eventCount > 0) {
          this.onDrag(event, eventLeft, eventTop, eventRight, eventBottom, eventCount > 1);
        }
      }
      if (event.type === TouchType.Up) {
        this.isTouched = false;
      }
    })

  }
}

@Component
export struct CropView {
  @State private model: CropModel = new CropModel();
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State private matrix: object = Matrix4.identity()
    .translate({ x: 0, y: 0 })
    .scale({ x: this.model.scale, y: this.model.scale });
  private tempScale = 1;
  private startOffsetX: number = 0;
  private startOffsetY: number = 0;

  build() {
    Stack() {
      Image(this.model.src)
        .width('100%')
        .height('100%')
        .alt(this.model.previewSource)
        .objectFit(ImageFit.Contain)
        .transform(this.matrix)
        .onComplete((msg) => {

          if (msg) {
            this.model.imageWidth = msg.width;
            this.model.imageHeight = msg.height;
            this.model.componentWidth = msg.componentWidth;
            this.model.componentHeight = msg.componentHeight;
            this.checkImageAdapt();

            if (this.model.imageLoadEventListener != null && msg.loadingStatus == 1) {
              this.model.imageLoadEventListener.onImageLoaded(msg);
            }
          }
        })
        .onError((error) => {
          if (this.model.imageLoadEventListener != null) {
            this.model.imageLoadEventListener.onImageLoadError(error);
          }
        })

      Canvas(this.context)
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .onReady(() => {
          if (this.context == null) {
            return
          }
          let height = this.context.height
          let width = this.context.width
          this.context.fillStyle = this.model.maskColor;
          this.context.fillRect(0, 0, width, height)

          let centerX = width / 2;
          let centerY = height / 2;

          this.context.globalCompositeOperation = 'destination-out'
          this.context.fillStyle = 'white'

          this.context.beginPath();
          this.context.arc(centerX, centerY, px2vp(this.model.frameWidth / 2), 0, 2 * Math.PI);
          this.context.fill();

          this.context.globalCompositeOperation = 'source-over';
          this.context.strokeStyle = this.model.strokeColor;

          this.context.beginPath();
          this.context.arc(centerX, centerY, px2vp(this.model.frameWidth / 2), 0, 2 * Math.PI);
          this.context.closePath();
          this.context.lineWidth = 1;
          this.context.stroke();
          this.context.clip()
        })
        .clip(true)
        .enabled(false)
    }
    .clip(true)
    .width('100%')
    .height('100%')
    .backgroundColor("#00000080")
    .priorityGesture(
      TapGesture({ count: 2, fingers: 1 })
        .onAction((event: GestureEvent) => {
          if (!event) {
            return
          }
          if (this.model.zoomEnabled) {
            if (this.model.scale != 1) {
              this.model.scale = 1;
              this.model.reset();
              this.updateMatrix();
            } else {
              this.zoomTo(2);
            }
          }
          this.checkImageAdapt();
        })
    )
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PanGesture({})
          .onActionStart(() => {
            this.startOffsetX = this.model.offsetX;
            this.startOffsetY = this.model.offsetY;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (event) {
              if (this.model.panEnabled) {
                let distanceX: number = this.startOffsetX + vp2px(event.offsetX) / this.model.scale;
                let distanceY: number = this.startOffsetY + vp2px(event.offsetY) / this.model.scale;
                this.model.offsetX = distanceX;
                this.model.offsetY = distanceY;
                this.updateMatrix()
              }
            }
          })
          .onActionEnd(() => {
            this.checkImageAdapt();
          }),

        PinchGesture({ fingers: 2 })
          .onActionStart(() => {
            this.tempScale = this.model.scale
          })
          .onActionUpdate((event) => {
            if (event) {
              if (!this.model.zoomEnabled) {
                return;
              }
              this.zoomTo(this.tempScale * event.scale);
            }
          })
          .onActionEnd(() => {
            this.checkImageAdapt();
          })
      )
    )
  }

  checkImageAdapt() {
    let offsetX = this.model.offsetX;
    let offsetY = this.model.offsetY;
    let scale = this.model.scale;

    let widthScale = this.model.componentWidth / this.model.imageWidth;
    let heightScale = this.model.componentHeight / this.model.imageHeight;
    let adaptScale = Math.min(widthScale, heightScale);

    let showWidth = this.model.imageWidth * adaptScale * this.model.scale;
    let showHeight = this.model.imageHeight * adaptScale * this.model.scale;
    let imageX = (this.model.componentWidth - showWidth) / 2;
    let imageY = (this.model.componentHeight - showHeight) / 2;

    let frameX = (this.model.componentWidth - this.model.frameWidth) / 2;
    let frameY = (this.model.componentHeight - this.model.getFrameHeight()) / 2;

    let showX = imageX + offsetX * scale;
    let showY = imageY + offsetY * scale;

    if (this.model.frameWidth > showWidth || this.model.getFrameHeight() > showHeight) {
      let xScale = this.model.frameWidth / showWidth;
      let yScale = this.model.getFrameHeight() / showHeight;
      let newScale = Math.max(xScale, yScale);
      this.model.scale = this.model.scale * newScale;
      showX *= newScale;
      showY *= newScale;
    }

    if (showX > frameX) {
      showX = frameX;
    } else if (showX + showWidth < frameX + this.model.frameWidth) {
      showX = frameX + this.model.frameWidth - showWidth;
    }
    if (showY > frameY) {
      showY = frameY;
    } else if (showY + showHeight < frameY + this.model.getFrameHeight()) {
      showY = frameY + this.model.getFrameHeight() - showHeight;
    }
    this.model.offsetX = (showX - imageX) / scale;
    this.model.offsetY = (showY - imageY) / scale;
    this.updateMatrix();
  }

  public zoomTo(scale: number): void {
    this.model.scale = scale;
    this.updateMatrix();
  }

  public updateMatrix(): void {
    this.matrix = Matrix4.identity()
      .translate({ x: this.model.offsetX, y: this.model.offsetY })
      .scale({ x: this.model.scale, y: this.model.scale })
  }
}

export class CropModel {
  src: string = '';
  previewSource: string | Resource = '';
  panEnabled: boolean = true;
  zoomEnabled: boolean = true;
  frameWidth = 1000;
  frameRatio = 1;
  maskColor: string = '#AA000000';
  strokeColor: string = '#FFFFFF';
  imageLoadEventListener: ImageLoadEventListener | null = null;
  imageWidth: number = 0;
  imageHeight: number = 0;
  componentWidth: number = 0;
  componentHeight: number = 0;
  scale: number = 1;
  offsetX: number = 0;
  offsetY: number = 0;

  public setImage(src: string, previewSource?: string | Resource): CropModel {
    this.src = src;
    if (!!previewSource) {
      this.previewSource = previewSource;
    }
    return this;
  }

  public setScale(scale: number): CropModel {
    this.scale = scale;
    return this;
  }

  public isPanEnabled(): boolean {
    return this.panEnabled;
  }

  public setPanEnabled(panEnabled: boolean): CropModel {
    this.panEnabled = panEnabled;
    return this;
  }

  public setZoomEnabled(zoomEnabled: boolean): CropModel {
    this.zoomEnabled = zoomEnabled;
    return this;
  }

  public setFrameWidth(frameWidth: number): CropModel {
    this.frameWidth = frameWidth;
    return this;
  }

  public setFrameRatio(frameRatio: number): CropModel {
    this.frameRatio = frameRatio;
    return this;
  }

  public setMaskColor(color: string): CropModel {
    this.maskColor = color;
    return this;
  }

  public setStrokeColor(color: string): CropModel {
    this.strokeColor = color;
    return this;
  }

  public setImageLoadEventListener(listener: ImageLoadEventListener): CropModel {
    this.imageLoadEventListener = listener;
    return this;
  }

  public getScale(): number {
    return this.scale;
  }

  public isZoomEnabled(): boolean {
    return this.zoomEnabled;
  }

  public getImageWidth(): number {
    return this.imageWidth;
  }

  public getImageHeight(): number {
    return this.imageHeight;
  }

  public getFrameHeight() {
    return this.frameWidth / this.frameRatio;
  }

  public reset(): void {
    this.scale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
  }

  public async crop(format: image.PixelMapFormat): Promise<image.PixelMap> {
    if (!this.src || this.src == '') {
      throw new Error('Please set src first');
    }
    if (this.imageWidth == 0 || this.imageHeight == 0) {
      throw new Error('The image is not loaded');
    }
    let widthScale = this.componentWidth / this.imageWidth;
    let heightScale = this.componentHeight / this.imageHeight;
    let adaptScale = Math.min(widthScale, heightScale);
    let totalScale = adaptScale * this.scale;
    let showWidth = this.imageWidth * totalScale;
    let showHeight = this.imageHeight * totalScale;
    let imageX = (this.componentWidth - showWidth) / 2;
    let imageY = (this.componentHeight - showHeight) / 2;
    let frameX = (this.componentWidth - this.frameWidth) / 2;
    let frameY = (this.componentHeight - this.getFrameHeight()) / 2;
    let showX = imageX + this.offsetX * this.scale;
    let showY = imageY + this.offsetY * this.scale;
    let x = (frameX - showX) / totalScale;
    let y = (frameY - showY) / totalScale;
    let file = fs.openSync(this.src, fs.OpenMode.READ_ONLY)
    let imageSource: image.ImageSource = image.createImageSource(file.fd);
    let decodingOptions: image.DecodingOptions = {
      editable: true,
      desiredPixelFormat: image.PixelMapFormat.BGRA_8888,
    }
    let pm = await imageSource.createPixelMap(decodingOptions);
    let cp = await this.copyPixelMap(pm);
    pm.release();
    let region: image.Region =
      { x: x, y: y, size: { width: this.frameWidth / totalScale, height: this.getFrameHeight() / totalScale } };
    cp.cropSync(region);
    return cp;
  }

  async copyPixelMap(pm: PixelMap): Promise<PixelMap> {
    const imageInfo: image.ImageInfo = await pm.getImageInfo();
    const buffer: ArrayBuffer = new ArrayBuffer(pm.getPixelBytesNumber());
    await pm.readPixelsToBuffer(buffer);
    const opts: image.InitializationOptions = {
      editable: true,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      size: { height: imageInfo.size.height, width: imageInfo.size.width }
    };
    return image.createPixelMap(buffer, opts);
  }
}

export interface ImageLoadEventListener {
  onImageLoaded(msg: ImageLoadedEvent): void;
  onImageLoadError(error: ImageError): void;
}

interface ImageLoadedEvent {
  width: number;
  height: number;
  componentWidth: number;
  componentHeight: number;
  loadingStatus: number;
  contentWidth: number;
  contentHeight: number;
  contentOffsetX: number;
  contentOffsetY: number;
}


@Extend(Row)
function rowStyle() {
  .width('100%')
  .height(1)
  .backgroundColor('#FFFFFF')
  .opacity(0.5)
}

@Extend(Row)
function rowStyle1(hasSplitLine: boolean) {
  .width('100%')
  .height(0.5)
  .backgroundColor('#FFFFFF')
  .opacity(hasSplitLine ? 0.5 : 0)
}

@Extend(Row)
function rowStyle2(hasMoreSplitLine: boolean) {
  .width('100%')
  .height(0.5)
  .backgroundColor('#FFFFFF')
  .opacity(hasMoreSplitLine ? 0.2 : 0)
}

@Extend(Column)
function columnStyle() {
  .width(1)
  .height('100%')
  .backgroundColor('#FFFFFF')
  .opacity(0.5)
}

@Extend(Column)
function columnStyle1(hasSplitLine: boolean) {
  .width(0.5)
  .height('100%')
  .backgroundColor('#FFFFFF')
  .opacity(hasSplitLine ? 0.5 : 0)
}

@Extend(Column)
function columnStyle2(hasMoreSplitLine: boolean) {
  .width(0.5)
  .height('100%')
  .backgroundColor('#FFFFFF')
  .opacity(hasMoreSplitLine ? 0.2 : 0)
}

@Extend(Image)
function iconStyle() {
  .size({ width: 24, height: 24 })
  .fillColor('#FFFFFF')
  .opacity(0.9)
}

@Extend(Row)
function bottomIconStyle() {
  .size({ width: '20%', height: '100%' })
  .justifyContent(FlexAlign.Center)
}

@Extend(Text)
function textStyle() {
  .size({ width: '20%', height: '100%' })
  .textAlign(TextAlign.Center)
}