(module
    (export "init" (func $init))
    (export "draw" (func $draw))
    (export "fill" (func $fill))
    ;;(export "setPixel" (func $setPixel))
    ;;(export "c_s_u" (func $c_s_u))
    (import "js" "memory" (memory 16))
    (global $width (mut i32) (i32.const 0))
    (global $height (mut i32) (i32.const 0))
    (global $stride (mut i32) (i32.const 0))

    (global $prev_x0 (mut i32) (i32.const 0))
    (global $prev_y0 (mut i32) (i32.const 0))
    (global $prev_x1 (mut i32) (i32.const 0))
    (global $prev_y1 (mut i32) (i32.const 0))
    (global $errorCN (mut i32) (i32.const 0))
    (global $steep (mut i32) (i32.const 0))

    (func $init (param $width i32) ;; width.
                 (param $height i32) ;; height.
                 (param $stride i32) ;; stride: width * 4, if we assume rgba.
        
        (global.set $width (local.get $width))
        (global.set $height (local.get $width))
        (global.set $stride (local.get $stride))
    )
    (func $draw
        (param $x0 i32) (param $y0 i32) (param $x1 i32) (param $y1 i32) (param $color i64)(param $clearPrevious i32)
        
        (local $steep i32)
        (local $derror i32)
        (local $dx i32)
        ;; errorCN -Composite number.
        ;; Contains two numbers for management error value
        (local $errorCN i32)
        (local $error i32)
        (local $x i32)
        (local $y i32)
        (local $pixel i32)
        (local $stride i32)
        (local $errorSign i32)

        (if (i32.eq(local.get $clearPrevious)(i32.const 1))
            (then 
                (call $draw
                    (global.get $prev_x0)
                    (global.get $prev_y0)
                    (global.get $prev_x1)
                    (global.get $prev_y1)
                    ;;(i32.const 255)
                    (i64.shl (i64.const 255) (i64.const 24))
                    (i32.const 0)
                )
 
                (global.set $prev_x0 (local.get $x0))
                (global.set $prev_y0 (local.get $y0))
                (global.set $prev_x1 (local.get $x1))
                (global.set $prev_y1 (local.get $y1))
            )
        )

        (local.set $stride (global.get $stride))

        ;; if the line is steep, we transpose the coordinates
        ;; if (Math.abs(x0 - x1) < Math.abs(y0 - y1))
        (if (i32.lt_s (call $c_s_u(i32.sub (local.get $x0) (local.get $x1))) (call $c_s_u(i32.sub (local.get $y0) (local.get $y1))))
            (then
                ;; [x0, y0] = [y0, x0]; or x0 = x0 ^ y0;
                (local.set $x0 (i32.xor( local.get $x0)(local.get $y0) ))
                (local.set $y0 (i32.xor( local.get $x0)(local.get $y0) ))
                (local.set $x0 (i32.xor( local.get $x0)(local.get $y0) ))
                
                ;; [x1, y1] = [y1, x1];
                (local.set $x1 (i32.xor( local.get $x1)(local.get $y1) ))
                (local.set $y1 (i32.xor( local.get $x1)(local.get $y1) ))
                (local.set $x1 (i32.xor( local.get $x1)(local.get $y1) ))

                ;; steep = true;
                (local.set $steep (i32.const 1))

                ;; ;; xy = x << 16 + y;
                ;; (local.set $xy
                ;;     (i32.add
                ;;         (i32.shl(local.get $x0)(i32.const 16))
                ;;         (local.get $y0)
                ;;     )
                ;; )
            )
            (else
                ;; steep = false;
                (local.set $steep (i32.const 0))

                ;; ;; xy = y << 16 + x;
                ;; (local.set $xy
                ;;     (i32.add
                ;;         (i32.shl(local.get $y0)(i32.const 16))
                ;;         (local.get $x0)
                ;;     )
                ;; )
            )
        )
        
        ;; make it left-to-right if (x0 > x1)
        (if (i32.gt_s (local.get $x0)(local.get $x1) )
            (then
                ;; [x0, x1] = [x1, x0]; or x0 = x0 ^ x1;
                (local.set $x0 (i32.xor(local.get $x0)(local.get $x1) ))
                (local.set $x1 (i32.xor(local.get $x0)(local.get $x1) ))
                (local.set $x0 (i32.xor(local.get $x0)(local.get $x1) ))
                
                ;; [y0, y1] = [y1, y0];
                (local.set $y0 (i32.xor(local.get $y0)(local.get $y1) ))
                (local.set $y1 (i32.xor(local.get $y0)(local.get $y1) ))
                (local.set $y0 (i32.xor(local.get $y0)(local.get $y1) ))
            )
        )

        ;; dx = x1 - x0;
        (local.set $dx(i32.sub (local.get $x1)(local.get $x0) ))

        ;; derror = Math.abs(dy) * 2;
        (local.set $derror 
            (i32.mul
                ;; Math.abs(dy);
                (call $c_s_u
                    ;; dy = y1 - y0;
                    (i32.sub
                        (local.get $y1)
                        (local.get $y0)
                    )
                )
                (i32.const 2) 
            )
        )
        ;; x = x0;
        (local.set $x (local.get $x0))
        ;; y = y0;
        (local.set $y (local.get $y0))
        
        ;; errorCN. 
        ;; This assigning is a little bit tricky and confused.
        ;; The whole purpose of this is erasing of "if" condition.
        ;; Below you can observe JS code with "if" condition
        ;; const yadd = y1 > y0 ? 1 : -1;
        ;; const dx2 = x1 - x0 * 2;
        ;; const _setError = () => {
        ;;     error += derror;
        ;;     if (error > dx) {
        ;;         y += yadd;
        ;;         error -= dx2;
        ;;     }
        ;; }
        ;;errorCN = (yadd << 16) + dx2;
        (local.set $errorCN
            (i32.add
                ;; (yadd << 16)
                (i32.shl
                    ;; yadd = y1 > y0 ? 1 : -1;
                    ;; y1 > y0 == 1 | ((y1 - y0) >> 31);
                    ;; 1 | ((y1 - y0) >> 31);
                    (i32.or
                        (i32.const 1)
                        ;; ((y1 - y0) >> 31);
                        (i32.shr_s
                            ;; (y1 - y0);
                            (i32.sub (local.get $y1) (local.get $y0))
                            (i32.const 31)
                        )
                    )
                    (i32.const 16)   
                )
                ;; dx2 = dx * 2;
                (i32.mul (local.get $dx) (i32.const 2))
            )
        )

        (block $drawing-loop
            (if (i32.eq(local.get $steep)(i32.const 1))
                (then
                    (loop $draw-loop ;; for (let i = 0; x < x1; x++, i++)
                        (if (i32.lt_s (local.get $x) (local.get $x1))
                            (then
                                (local.set $pixel
                                    (i32.add
                                        (i32.mul
                                            (local.get $x)
                                            (local.get $stride)
                                        )
                                        (i32.mul
                                            (local.get $y)
                                            (i32.const 4)
                                        )
                                    )
                                )
                                (i64.store32 (local.get $pixel)(local.get $color))
                                
                                ;; set error
                                ;;error += derror;
                                (local.set $error (i32.add (local.get $error)(local.get $derror)))
                                ;; errorSign = (error - dx) >> 31;
                                (local.set
                                    $errorSign
                                    (i32.shr_s
                                        (i32.sub
                                            (local.get $error)
                                            (local.get $dx)
                                        )
                                        (i32.const 31)
                                    )
                                )
                                ;; ++errorSign
                                (local.set $errorSign (i32.add(local.get $errorSign)(i32.const 1)))
                                ;;  y += (errorLut >> 16) * errorSign;
                                (local.set $y
                                    (i32.add
                                        (local.get $y)
                                        (i32.mul
                                            (i32.shr_s
                                                (local.get $errorCN)
                                                (i32.const 16)
                                            )
                                            (local.get $errorSign)
                                        )
                                    )
                                )
                                ;; error -= (errorLut & 65535) * errorSign;
                                (local.set $error
                                    (i32.sub
                                        (local.get $error)
                                        (i32.mul
                                            (i32.and
                                                (local.get $errorCN)
                                                (i32.const 65535)
                                            )
                                            (local.get $errorSign)
                                        )
                                    )
                                )

                                ;; x++
                                (i32.add (local.get $x) (i32.const 1)) ;; x + 1
                                (local.set $x) ;; set new result to 'x'
                                br $draw-loop ;; continue
                            )
                        )
                    )
                )
                (else
                    (loop $draw-loop ;; for (let i = 0; x < x1; x++, i++)
                        (if (i32.lt_s (local.get $x) (local.get $x1))
                            (then
                                (local.set $pixel
                                    (i32.add
                                        (i32.mul
                                            (local.get $y)
                                            (local.get $stride)
                                        )
                                        (i32.mul
                                            (local.get $x)
                                            (i32.const 4)
                                        )
                                    )
                                )
                                (i64.store32 (local.get $pixel)(local.get $color))

                                ;; set error
                                ;;error += derror;
                                (local.set $error (i32.add (local.get $error)(local.get $derror)))
                                ;; errorSign = (error - dx) >> 31;
                                (local.set
                                    $errorSign
                                    (i32.shr_s
                                        (i32.sub
                                            (local.get $error)
                                            (local.get $dx)
                                        )
                                        (i32.const 31)
                                    )
                                )
                                ;; ++errorSign
                                (local.set $errorSign (i32.add(local.get $errorSign)(i32.const 1)))
                                ;;  y += (errorLut >> 16) * ++errorSign;
                                (local.set $y
                                    (i32.add
                                        (local.get $y)
                                        (i32.mul
                                            (i32.shr_s
                                                (local.get $errorCN)
                                                (i32.const 16)
                                            )
                                            (local.get $errorSign)
                                        )
                                    )
                                )
                                ;; error -= ((errorLut << 16) >>> 16) * errortmp;
                                (local.set $error
                                    (i32.sub
                                        (local.get $error)
                                        (i32.mul
                                            (i32.shr_u
                                                (i32.shl
                                                    (local.get $errorCN)
                                                    (i32.const 16)
                                                )
                                                (i32.const 16)
                                            )
                                            (local.get $errorSign)
                                        )
                                    )
                                )

                                ;; x++
                                (i32.add (local.get $x) (i32.const 1)) ;; x + 1
                                (local.set $x) ;; set new result to 'x'
                                br $draw-loop ;; continue
                            )
                        )
                    )
                )
            )
        )
        ;;(local.get $errorCN) ;; just return 0
    )


    (func $fill (param $color i64) ;; alpha color

        (local $pixel i32)
        (local $height i32)
        (local $width i32)
        (local $i i32)
        (local $j i32)
        (local $stride i32)

        (local.set $pixel (i32.const 0))
        (local.set $height (global.get $height))
        (local.set $width (global.get $width))
        (local.set $i (i32.const 0))
        (local.set $j (i32.const 0))
        (local.set $stride (global.get $stride))
        
        (loop $clear-loop|0 ;; for (let i = 0; i < height; i++)
            (if (i32.lt_s (local.get $i) (local.get $height)) ;; if(i < height)
                (then
                    (local.set $j (i32.const 0)) ;; let j = 0.
                    (loop $clear-loop|1 ;; for (let j = 0; j < width; i++)
                        (if (i32.lt_s (local.get $j) (local.get $width)) ;; if(j < width)
                            (then
                                ;; pixel = i * stride + j * 4;
                                (i32.add 
                                    (i32.mul (local.get $i) (local.get $stride)) ;; i * stride
                                    (i32.mul (local.get $j) (i32.const 4)) ;; j * 4
                                )
                                (local.set $pixel)

                                (i64.store32 (local.get $pixel)(local.get $color))
                                
                                ;; j++
                                (i32.add (local.get $j) (i32.const 1)) ;; j + 1
                                (local.set $j) ;; set new result to 'j'
                                br $clear-loop|1 ;; continue
                            )
                        )
                    )
                    
                    ;; i++
                    (i32.add (local.get $i) (i32.const 1)) ;; i + 1
                    (local.set $i) ;; set new result to 'i'
                    br $clear-loop|0 ;; continue
                )
            )
        )
    )
    ;; (func $setPixel (param $pixel i32) (param $color i32)
    ;;     (i32.store (local.get $pixel)                        (i32.and (i32.shr_s (local.get $color)(i32.const 24)) (i32.const 255) )) ;; this.data[pixel] = r;
    ;;     (i32.store (i32.add (local.get $pixel)(i32.const 1)) (i32.and (i32.shr_s (local.get $color)(i32.const 16)) (i32.const 255) )) ;; this.data[pixel + 1] = g;
    ;;     (i32.store (i32.add (local.get $pixel)(i32.const 2)) (i32.and (i32.shr_s (local.get $color)(i32.const 8)) (i32.const 255) )) ;; this.data[pixel + 2] = b;
    ;;     (i32.store (i32.add (local.get $pixel)(i32.const 3)) (i32.and (local.get $color)(i32.const 255))) ;; this.data[pixel + 3] = a;
    ;; )
    ;; Convert 32bit number with negative sign to positive
    ;; return (1 | (value >> 31)) * value;
    (func $c_s_u (param $value i32) (result i32)
        (i32.mul ;; (1 | (value >> 31)) * value
            (i32.or ;; (1 | (value >> 31))
                (i32.shr_s ;; (value >> 31)
                    (local.get $value)
                    (i32.const 31)
                )
                (i32.const 1)
            )
            (local.get $value)
        )
    )
)