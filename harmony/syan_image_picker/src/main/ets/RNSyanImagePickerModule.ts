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

import { TurboModule, TurboModuleContext } from '@rnoh/react-native-openharmony/ts';
import { TM } from "@rnoh/react-native-openharmony/generated/ts"
import { ImagePickerOption, ImagePickerResponseData, SelectedPhoto } from "./model/Model"
import Logger from './Logger';
import image from '@ohos.multimedia.image';
import util from '@ohos.util';
import { BusinessError } from '@ohos.base';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { JSON, List } from '@kit.ArkTS';
import { cameraPicker } from '@kit.CameraKit';
import { media } from '@kit.MediaKit';

export class RNSyanImagePickerTurboModule extends TurboModule implements TM.RNSyanImagePicker.Spec {
  private static TAG: string = "[RNSyanImagePickerTurboModule.ts]";
  private selectList: Array<SelectedPhoto> = new Array();

  constructor(protected ctx: TurboModuleContext) {
    super(ctx);
  }

  isNullOrUndefined(value): boolean {
    return value === null || value === undefined || value === '';
  }

  /**
   *
   * @param options : Selection configuration items passed by the client
   * @param imageOrVideo : True selects photo, false selects video
   * @returns
   */
  private buildSelectOption(options: ImagePickerOption, imageOrVideo: boolean): photoAccessHelper.PhotoSelectOptions {
    let optionsPassedToOHSelector: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    const ONLY_ONE_NUMBER: number = 1;

    switch (imageOrVideo) {
      case true:
        optionsPassedToOHSelector.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
        optionsPassedToOHSelector.maxSelectNumber = options.isCrop ? ONLY_ONE_NUMBER : options.imageCount;
        optionsPassedToOHSelector.isPhotoTakingSupported = options.isCamera;
        optionsPassedToOHSelector.isEditSupported = options.isCrop;
        break;

      case false:
        optionsPassedToOHSelector.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
        optionsPassedToOHSelector.maxSelectNumber =
          options.allowPickingMultipleVideo ? options.videoCount : ONLY_ONE_NUMBER;
        break;
      default:
        break;
    }

    return optionsPassedToOHSelector;
  }

  private extractImageOrVideoType(srcPath: string): string | undefined {
    const i = srcPath.lastIndexOf('.');
    if (i !== -1) {
      return srcPath.substring(i + 1);
    }
    return undefined;
  }

  private isImage(filePath: string): boolean {
    const imageExtensionsRegex = /\.(jpg|jpeg|png|gif|bmp|webp)$/i;
    return imageExtensionsRegex.test(filePath);
  }

  private isVideo(videoSrc: string): boolean {
    const videoExtensionsRegex = /\.(mp4|mkv|ts)$/i;
    return videoExtensionsRegex.test(videoSrc);
  }

  private imageToBase64(src: string): string {
    let base64Data;
    try {
      let file = fs.openSync(src, fs.OpenMode.READ_ONLY);
      let stat = fs.lstatSync(src);
      let buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      let unit8Array: Uint8Array = new Uint8Array(buf);
      let base64Helper = new util.Base64Helper();
      base64Data = base64Helper.encodeToStringSync(unit8Array, util.Type.BASIC);
      fs.closeSync(file);
    } catch (err) {
      Logger.error(RNSyanImagePickerTurboModule.TAG, 'into imageToBase64 err: ' + JSON.stringify(err));
    }
    return base64Data;
  }

  private async cacheImageFiles(context: common.UIAbilityContext, src: string, cacheSrcResultArray: Array<string>) {
    const imageType = this.extractImageOrVideoType(src);
    if (!imageType) {
      Logger.warn(RNSyanImagePickerTurboModule.TAG, 'Unable to extract image type from path: ' + src);
      return;
    }

    /**
     * Copy file destination path
     */
    const dstPath: string =
      `${context.cacheDir}/rn_syan_image_picker_lib_cache_${util.generateRandomUUID(true)}.${imageType}`;
    let file: fs.File | null = null;

    try {
      file = await fs.open(src, fs.OpenMode.READ_ONLY);
    } catch (openFileError) {
      Logger.error(RNSyanImagePickerTurboModule.TAG,
        'Failed to open file: ' + src + ' Error: ' + openFileError.toString());
      return;
    }

    try {
      await fs.copyFile(file.fd, dstPath);
      cacheSrcResultArray.push(dstPath);
    } catch (copyFileError) {
      Logger.error(RNSyanImagePickerTurboModule.TAG,
        'Failed to copy file from: ' + src + ' to: ' + dstPath + ' Error: ' + copyFileError.toString());
    } finally {
      if (file) {
        try {
          await fs.close(file.fd);
        } catch (closeErr) {
          Logger.error(RNSyanImagePickerTurboModule.TAG,
            'Failed to close file descriptor: ' + file.fd + ' Error: ' + closeErr.toString());
        }
      }
    }
  }

  private async getCacheFilePathLists(images: Array<string>): Promise<Array<string>> {
    const len: number = images.length;
    if (!images && len === 0) {
      Logger.info(RNSyanImagePickerTurboModule.TAG, 'getTempFilePaths images is null or empty');
      return [];
    }
    let cacheFileSrcLists: Array<string> = new Array<string>();
    const context = this.ctx.uiAbilityContext;

    const cacheImagePromises = images.map(async (srcPath) => {
      if (this.isImage(srcPath)) {
        try {
          await this.cacheImageFiles(context, srcPath, cacheFileSrcLists);
        } catch (error) {
          Logger.error(RNSyanImagePickerTurboModule.TAG,
            'Error caching image file: ' + srcPath + ' Error: ' + JSON.stringify(error));
        }
      }

      if (this.isVideo(srcPath)) {
        try {
          await this.cacheImageFiles(context, srcPath, cacheFileSrcLists);
        } catch (error) {
          Logger.error(RNSyanImagePickerTurboModule.TAG,
            'Error caching video file: ' + srcPath + ' Error: ' + JSON.stringify(error));
        }
      }
    });

    await Promise.all(cacheImagePromises);
    return cacheFileSrcLists;
  }

  private async compressPictures(quality: number, sourceURLs: Array<string>): Promise<Array<string>> {
    const compressedPaths: Array<string> = await Promise.all(
      sourceURLs.map(async (srcPath: string) => {
        if (!this.isImage(srcPath)) {
          return null;
        }

        const imageType = this.extractImageOrVideoType(srcPath);
        let files: fs.File | null = null;
        let imageISs: image.ImageSource | null = null;
        let imagePMs: image.PixelMap | null = null;
        let imagePackerApi: image.ImagePacker | null = null;
        let newFile: fs.File | null = null;

        try {
          files = fs.openSync(srcPath, fs.OpenMode.READ_ONLY);
          imageISs = image.createImageSource(files.fd);
          imagePMs = await imageISs.createPixelMap();
          imagePackerApi = image.createImagePacker();

          const options: image.PackingOption = {
            format: 'image/jpeg',
            quality: quality
          };
          const packerData: ArrayBuffer = await imagePackerApi.packing(imagePMs, options);

          /**
           * The target path for saving compressed images
           */
          const dstPath =
            `${this.ctx.uiAbilityContext.cacheDir}/rn_syan_image_picker_lib_compress_cache_${util.generateRandomUUID(true)}.${imageType}`;
          newFile = fs.openSync(dstPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);

          fs.writeSync(newFile.fd, packerData);
          Logger.info(RNSyanImagePickerTurboModule.TAG, 'into compressPictures write data to file succeeded');

          return dstPath;
        } catch (error) {
          Logger.error(RNSyanImagePickerTurboModule.TAG, 'compressPictures error: ' + error.toString());
          return null;
        } finally {
          if (files) {
            fs.closeSync(files);
          }
          if (imageISs) {
            await imageISs.release();
          }
          if (imagePMs) {
            await imagePMs.release();
          }
          if (imagePackerApi) {
            await imagePackerApi.release();
          }
          if (newFile) {
            fs.closeSync(newFile);
          }
        }
      })
    );

    // Filter out null values (if any image compression fails)
    return compressedPaths.filter(Boolean);
  }

  private async buildSelectedPhotoObj(srcPatch: string, originalUri: string,
    includeBase64: boolean): Promise<SelectedPhoto> {
    const selectedPhoto: SelectedPhoto = new SelectedPhoto();
    /**
     * Set the uri property of the response data SelectedPhoto object
     */
    selectedPhoto.uri = "file://" + srcPatch;
    /**
     * Set the original_uri property of the response data SelectedPhoto object
     */
    selectedPhoto.original_uri = originalUri;
    let file: fs.File | null = null;

    try {
      file = fs.openSync(srcPatch, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      /**
       * Set the size property of the response data SelectedPhoto object
       */
      selectedPhoto.size = stat.size;
      /**
       *  Set the base64 property of the response data SelectedPhoto object
       */
      selectedPhoto.base64 = includeBase64 ? this.imageToBase64(srcPatch) : '';
      /**
       * Photo
       */
      if (this.isImage(srcPatch)) {
        /**
         * Set the type property of the response data SelectedPhoto object
         */
        selectedPhoto.type = this.extractImageOrVideoType(srcPatch);
        const imageIS = image.createImageSource(file.fd);
        const imagePM = await imageIS.createPixelMap();
        const imgInfo = await imagePM.getImageInfo();
        /**
         * Set the height property of the response data SelectedPhoto object
         */
        selectedPhoto.height = imgInfo.size.height;
        /**
         * Set the width property of the response data SelectedPhoto object
         */
        selectedPhoto.width = imgInfo.size.width;
        /**release**/
        await Promise.all([imagePM.release(), imageIS.release()]);
        /**
         * video
         */
      } else if (this.isVideo(srcPatch)) {
        /**
         * Set the type property of the response data SelectedPhoto object
         */
        selectedPhoto.type = this.extractImageOrVideoType(srcPatch);
        const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
        avMetadataExtractor.fdSrc = { fd: file.fd };
        const resOfAVMetadata: media.AVMetadata = await avMetadataExtractor.fetchMetadata();
        /**
         * Set the width property of the response data SelectedPhoto object
         */
        selectedPhoto.width = parseInt(resOfAVMetadata.videoWidth, 10);
        /**
         * Set the height property of the response data SelectedPhoto object
         */
        selectedPhoto.height = parseInt(resOfAVMetadata.videoHeight, 10);
      }
    } catch (err) {
      Logger.error(RNSyanImagePickerTurboModule.TAG, `Error processing image: ${JSON.stringify(err)}`);
      throw err;
    } finally {
      if (file) {
        fs.closeSync(file.fd);
      }
    }
    return selectedPhoto;
  }

  private async getPickerResult(request: ImagePickerOption, sourceFilePaths: Array<string>,
    cacheFilePaths?: Array<string>): Promise<ImagePickerResponseData> {
    let images: string[] = this.isNullOrUndefined(cacheFilePaths) ? sourceFilePaths : cacheFilePaths;
    let imagePickerResponseDataToClient: ImagePickerResponseData = new ImagePickerResponseData();
    const includeBase64 = request.enableBase64 ?? false;

    try {
      const getSelectedPhotoObj: Promise<SelectedPhoto>[] =
        images.map((src: string, index: number) => this.buildSelectedPhotoObj(src, sourceFilePaths[index],
          includeBase64));
      const newResults: SelectedPhoto[] = await Promise.all(getSelectedPhotoObj);
      /**
       * Store the result of each selection at the end of the select list array
       */
      this.selectList.push(...newResults);
      imagePickerResponseDataToClient.selectedPhoto = this.selectList;
    } catch (err) {
      imagePickerResponseDataToClient.errorMessage = `${err}`;
      imagePickerResponseDataToClient.selectedPhoto = [];
    }

    Logger.info(RNSyanImagePickerTurboModule.TAG,
      `getPickerResult selectedPhoto[] length : ${imagePickerResponseDataToClient.selectedPhoto}`);
    return imagePickerResponseDataToClient;
  }


  /**
   *
   * @param request : Client img Picker configuration item
   * @param callOHOSPicturePickerObtain : A selected image URL array obtained from the OHOS system selector
   * @returns ：ImagePickerResponseData
   */
  private async generateSelectedPhotoReturnedToTheClient(request: ImagePickerOption,
    callOHOSPicturePickerObtain: Array<string>): Promise<ImagePickerResponseData> {
    /**
     * Perform compression
     **/
    if (request && request.compress) {
      Logger.info(RNSyanImagePickerTurboModule.TAG, `Perform compression to obtain the compressed cache image uri`);
      const compressedImageURL: Array<string> =
        await this.compressPictures(request.quality, callOHOSPicturePickerObtain);

      const imagePickerResponseDataToClient: ImagePickerResponseData =
        await this.getPickerResult(request, callOHOSPicturePickerObtain, compressedImageURL);
      return imagePickerResponseDataToClient;
    }

    /**
     * Do not perform compression
     **/
    if (request && !(request.compress)) {
      Logger.info(RNSyanImagePickerTurboModule.TAG, "not Perform compression");
      const cacheFileSrcLists: string[] = await this.getCacheFilePathLists(callOHOSPicturePickerObtain);
      const imagePickerResponseDataToClient: ImagePickerResponseData =
        await this.getPickerResult(request, callOHOSPicturePickerObtain, cacheFileSrcLists);

      return imagePickerResponseDataToClient;
    }
  }

  private async importCameraModules() {
    try {
      const cameraModule = await import("@ohos.multimedia.camera");
      const cameraPickerModule = await import("@ohos.multimedia.cameraPicker");
      return { cameraModule, cameraPickerModule };
    } catch (error) {
      Logger.error(RNSyanImagePickerTurboModule.TAG, 'Error importing camera modules: ' + JSON.stringify(error));
      throw error;
    }
  }

  private async pickCamera(cameraPickerModule, mContext, mediaType, pickerProfile) {
    try {
      const pickerResult = await cameraPickerModule.default.pick(mContext, mediaType, pickerProfile);
      return pickerResult;
    } catch (error) {
      Logger.error(RNSyanImagePickerTurboModule.TAG, 'Error picking camera: ' + JSON.stringify(error));
      throw error;
    }
  }

  showImagePicker(options: ImagePickerOption, callback: (err: null | string, photos: SelectedPhoto[]) => void): void {
    const photoPicker = new photoAccessHelper.PhotoViewPicker();
    /*** Call the native image selector to obtain a set of URLs for the selected images**/
    photoPicker.select(this.buildSelectOption(options, true))
      .then((result: photoAccessHelper.PhotoSelectResult) => {
        return this.generateSelectedPhotoReturnedToTheClient(options, result.photoUris);
      })
      .then((imagePickerResponseDataToClient: ImagePickerResponseData) => {
        if (imagePickerResponseDataToClient.errorMessage) {
          callback(imagePickerResponseDataToClient.errorMessage, null);
        } else {
          callback(null, imagePickerResponseDataToClient.selectedPhoto);
        }
      })
      .catch((error) => {
        Logger.error(RNSyanImagePickerTurboModule.TAG,
          "Error launching image selector, error msg: " + JSON.stringify(error));
        callback(JSON.stringify(error), null);
      });
  }

  asyncShowImagePicker(options: ImagePickerOption): Promise<SelectedPhoto[]> {
    /*** Call the native image selector to obtain a set of URLs for the selected images**/
    const photoPicker = new photoAccessHelper.PhotoViewPicker();

    return photoPicker.select(this.buildSelectOption(options, true))
      .then((result: photoAccessHelper.PhotoSelectResult) => {
        return this.generateSelectedPhotoReturnedToTheClient(options, result.photoUris);
      })
      .then((imagePickerResponseDataToClient: ImagePickerResponseData) => {
        if (imagePickerResponseDataToClient.errorMessage) {
          return Promise.reject(new Error(imagePickerResponseDataToClient.errorMessage));
        }

        return imagePickerResponseDataToClient.selectedPhoto;
      })
      .catch((error) => {
        Logger.error(RNSyanImagePickerTurboModule.TAG, "Error launching image selector: " + JSON.stringify(error));
        return Promise.reject(error);
      });
  }

  openCamera(options: ImagePickerOption, callback: (err: null | string, photos: SelectedPhoto[]) => void): void {
    const handleError = (error: any) => {
      let errMsg: string;
      if (error) {
        errMsg = JSON.stringify(error);
      } else if (error instanceof Error) {
        errMsg = error.message;
      } else {
        errMsg = 'Unknown error occurred';
      }
      callback(errMsg, null);
      Logger.error(RNSyanImagePickerTurboModule.TAG, 'Error: ' + errMsg);
    };

    this.importCameraModules()
      .then(({ cameraModule, cameraPickerModule }) => {
        let mediaType: cameraPicker.PickerMediaType[] =
          [cameraPickerModule.default.PickerMediaType.PHOTO, cameraPickerModule.default.PickerMediaType.VIDEO];
        let mContext = this.ctx.uiAbilityContext;
        let pickerProfile = { cameraPosition: cameraModule.default.CameraPosition.CAMERA_POSITION_UNSPECIFIED };
        return this.pickCamera(cameraPickerModule, mContext, mediaType, pickerProfile);
      })

      .then((pickerResult) => {
        return this.generateSelectedPhotoReturnedToTheClient(options,
          pickerResult.resultCode === 0 ? [pickerResult.resultUri] : null);
      })

      .then((imagePickerResponseDataToClient: ImagePickerResponseData) => {
        if (imagePickerResponseDataToClient.errorMessage) {
          callback(imagePickerResponseDataToClient.errorMessage, null);
        } else {
          callback(null, imagePickerResponseDataToClient.selectedPhoto);
        }
      })
      .catch(handleError);
  }

  asyncOpenCamera(options: ImagePickerOption): Promise<SelectedPhoto[]> {
    return new Promise((resolve, reject) => {
      const handleError = (error: BusinessError) => {
        let errMsg: string;
        if (error) {
          errMsg = JSON.stringify(error);
        } else if (error instanceof Error) {
          errMsg = error.message;
        } else {
          errMsg = 'Unknown error occurred';
        }
        reject(errMsg);
        Logger.error(RNSyanImagePickerTurboModule.TAG, 'Error: ' + errMsg);
      };

      this.importCameraModules()
        .then(({ cameraModule, cameraPickerModule }) => {
          let mediaType: cameraPicker.PickerMediaType[] =
            [cameraPickerModule.default.PickerMediaType.PHOTO, cameraPickerModule.default.PickerMediaType.VIDEO];
          let mContext = this.ctx.uiAbilityContext;
          let pickerProfile = { cameraPosition: cameraModule.default.CameraPosition.CAMERA_POSITION_UNSPECIFIED };
          return this.pickCamera(cameraPickerModule, mContext, mediaType, pickerProfile);
        })

        .then((pickerResult: cameraPicker.PickerResult) => {
          return this.generateSelectedPhotoReturnedToTheClient(options,
            pickerResult.resultCode === 0 ? [pickerResult.resultUri] : null);
        })

        .then((imagePickerResponseDataToClient: ImagePickerResponseData) => {
          resolve(imagePickerResponseDataToClient.selectedPhoto);
        })
        .catch(handleError);
    });
  }

  deleteCache(): void {
    let cacheDirPath = this.ctx.uiAbilityContext.cacheDir;
    fs.rmdir(cacheDirPath)
      .then(() => {
        Logger.info(RNSyanImagePickerTurboModule.TAG, "deleteCache succeed");
      })
      .catch((err: BusinessError) => {
        Logger.error(RNSyanImagePickerTurboModule.TAG, "deleteCache error : " + err.toString());
        throw err;
      });
  }

  removePhotoAtIndex(index: number): void {
    if (this.selectList != null && this.selectList.length > index) {
      this.selectList.splice(index, 1);
    }
    Logger.info(RNSyanImagePickerTurboModule.TAG, " Select List after deleting index ：" + this.selectList.length + "");
  }

  removeAllPhoto(): void {
    if (this.selectList != null) {
      this.selectList = [];
    }
    Logger.info(RNSyanImagePickerTurboModule.TAG,
      "After deleting the content of the selectList, The length of the selectList" + this.selectList.length + "");
  }

  openVideoPicker(options: ImagePickerOption, callback: (err: null | string, photos: SelectedPhoto[]) => void): void {
    const photoPicker = new photoAccessHelper.PhotoViewPicker();
    /***Call the native image selector to obtain a set of URLs for the selected videos**/
    photoPicker.select(this.buildSelectOption(options, false))
      .then((videoSelectResultArr: photoAccessHelper.PhotoSelectResult) => {
        return this.generateSelectedPhotoReturnedToTheClient(options, videoSelectResultArr.photoUris);
      })
      .then((imagePickerResponseDataToClient: ImagePickerResponseData) => {
        if (imagePickerResponseDataToClient.errorMessage) {
          callback(imagePickerResponseDataToClient.errorMessage, null);
        } else {
          callback(null, imagePickerResponseDataToClient.selectedPhoto);
        }
      })
      .catch((error) => {
        Logger.error(RNSyanImagePickerTurboModule.TAG,
          "Error launching image selector, error msg : " + JSON.stringify(error));
        callback(JSON.stringify(error), null);
      });
  }
}
