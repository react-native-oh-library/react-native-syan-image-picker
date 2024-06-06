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

const MaxNumber: number = 6;

export class ImagePickerOption {
  imageCount?: number = MaxNumber; // Maximum number of selected images, default to 6
  isRecordSelected?: boolean; // Has an image been selected
  isCamera?: boolean = true; // Allow users to take photos internally, default to true
  isCrop?: boolean = false; // Is cropping allowed? Default false, imageCount takes effect only when imageCount is 1
  CropW?: number; // Crop width, default screen width of 60%
  CropH?: number; // Crop height, default screen width 60%
  isGif?: boolean =
    false; // Is it allowed to select GIF? The default is false, and there is currently no callback GIF data available
  showCropCircle?: boolean = false; // Display circular crop area, default false
  circleCropRadius?: number; // Circular cropping radius, default screen width half
  showCropFrame?: boolean = true; // Whether to display cropping area, default to true
  showCropGrid?: boolean; // Whether to hide the cropping area grid, default false
  freeStyleCropEnabled?: boolean; // Can the crop box be dragged
  rotateEnabled?: boolean; // Can cropping rotate images
  scaleEnabled?: boolean; // Can cropping enlarge or shrink images
  compress?: boolean = false;
  compressFocusAlpha?: boolean; //Compress PNG to retain brightness
  minimumCompressSize?: number; // Images smaller than 100 kb are not compressed
  quality?: number; // compression quality
  enableBase64?: boolean = false; // Whether to return base 64 encoding, default not to return
  allowPickingOriginalPhoto?: boolean;
  allowPickingMultipleVideo?: boolean; // Multiple video gif images can be selected
  videoMaximumDuration?: number; // The maximum shooting time of the video is 10 minutes by default, measured in seconds
  isWeChatStyle?: boolean;
  sortAscendingByModificationDate?: boolean; // Sort photos in ascending order by modification time, default to YES.
  videoCount?: number = MaxNumber; // Number of videos
  MaxSecond?: number; // Select the maximum video duration, which defaults to 180 seconds
  MinSecond?: number; // Select the minimum video duration, which defaults to 1 second
  showSelectedIndex?: boolean; //Is the serial number displayed? It is not displayed by default
}

export class SelectedPhoto {
  width: number; //image width
  height: number; //Image height
  uri: string; //Image path
  original_uri: string; //Image original path
  type: string; //File type, Android only, currently only returning image
  size: number; //Image size, in bytes b
  base64: string; //The base64 encoding of the image, if enableBase64 is set to false, does not return this property
}

export type ErrorCode = 'camera_unavailable' | 'permission' | 'others';

export class ImagePickerResponseData {
  errorCode?: ErrorCode;
  errorMessage?: string;
  selectedPhoto: SelectedPhoto[];
}