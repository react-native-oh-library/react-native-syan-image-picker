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

import fs from '@ohos.file.fs';
import image from '@ohos.multimedia.image';
import Logger from '../Logger';
import { Constants } from '../utils/Constants';
import util from '@ohos.util';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { abilityAccessCtrl } from '@kit.AbilityKit';


const TAG: string = 'imageEdit_Encode';


export async function encode(component: Object, pixelMap: ESObject,): Promise<string> {
  let imgPath: string = '';
  const newPixelMap: ESObject = pixelMap;
  const imagePackerApi = image.createImagePacker();
  const packOptions: image.PackingOption = {
    format: Constants.ENCODE_FORMAT,
    quality: Constants.ENCODE_QUALITY
  }
  let packerData = await imagePackerApi.packing(newPixelMap, packOptions);
  Logger.info(TAG, 'into compressPictures data: ' + JSON.stringify(packerData));
  const context = getContext(component);
  imgPath =
    context.filesDir + '/rn_image_crop_picker_lib_temp_' + util.generateRandomUUID(true) + Constants.IMAGE_FORMAT;
  let newFile = fs.openSync(imgPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
  Logger.info(TAG, 'into compressPictures newFile id: ' + newFile.fd);
  const number = fs.writeSync(newFile.fd, packerData);
  Logger.info(TAG, 'into compressPictures write data to file succeed size: ' + number);
  fs.closeSync(newFile.fd);
  imagePackerApi.release();
  return imgPath;
}