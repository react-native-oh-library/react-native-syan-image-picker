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

export class CropScaleClass {
  value: number;
  ratio: string;
  cropIndex: number;
  text: string | Resource;
  key: string = '';

  constructor(value: number, ratio: string, cropIndex: number, text: string | Resource, key?: string) {
    this.value = value;
    this.ratio = ratio;
    this.cropIndex = cropIndex;
    this.text = text;
    key && (this.key = key);
  }
}

export class DownPos{
  left: number
  top: number
  bottom: number
  right: number

  constructor(left: number, top: number, bottom: number, right: number) {
    this.left = left;
    this.top = top;
    this.bottom = bottom;
    this.right = right;
  }
}

export class DragObj{
  x: number
  y: number
  dragging: boolean
  action: Action
  downPos: DownPos
  multiCrop: boolean

  constructor(dragging: boolean, x: number = 0, y: number = 0,
              action: Action = new Action(false, false, false, false),
              downPos: DownPos = new DownPos(0, 0, 0, 0), multiCrop: boolean = false) {
    this.dragging = dragging;
    this.x = x;
    this.y = y;
    this.action = action;
    this.downPos = downPos;
    this.multiCrop = multiCrop;
  }
}

export class Action {
  left: boolean
  top: boolean
  right: boolean
  bottom: boolean

  constructor(left: boolean, top: boolean, right: boolean, bottom: boolean) {
    this.left = left;
    this.top = top;
    this.right = right;
    this.bottom = bottom;
  }
}

export enum CropType {
  FREE_CROP,
  FIXED_RATIO,
  FRAME_CROP
}