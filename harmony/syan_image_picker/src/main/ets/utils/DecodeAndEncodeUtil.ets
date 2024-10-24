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
import { Constants } from '../utils/Constants';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit'


const TAG: string = 'imageCrop_Decode_Encode';

/**
 * Async create pixel map.
 *
 * @return pixelMa.
 */
export async function getPixelMap(uri: string){
  const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
  const fd = file?.fd;
  // path为已获得的沙箱路径
  const imageSource = image.createImageSource(fd);
  const pixelMap = await imageSource.createPixelMap({
    editable: true
  });
  return pixelMap
}

export async function encode(component: Object, pixelMap: PixelMap) {
  const newPixelMap = pixelMap;
  // Packing image.
  const imagePackerApi = image.createImagePacker();
  const packOptions: image.PackingOption = {
    format: Constants.ENCODE_FORMAT,
    quality: Constants.ENCODE_QUALITY
  }
  const imageData = await imagePackerApi.packing(newPixelMap, packOptions);
  // Get album's path.
  const context = getContext(component);
  const media = photoAccessHelper.getPhotoAccessHelper(context);
  const currentTime = new Date().getTime();
  // Create image asset.
  const filePath = await media.createAsset(
    photoAccessHelper.PhotoType.IMAGE,
    `${Constants.IMAGE_PREFIX}_${currentTime}${Constants.IMAGE_FORMAT}`,
  );

  let file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
  await fs.write(file.fd, imageData);
  // Image resource release.
  imagePackerApi.release();
  await media.release();
}
