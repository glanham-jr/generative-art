(load "~/quicklisp/setup.lisp")
(ql:quickload :weird)
(ql:quickload :iterate)
(ql:quickload :veq)
(use-package :iterate)

"Vertex is a point, edge is a line connecting vertices, face is area of edges"


(defun coerce-float (x) (coerce x 'float))

(defglobal *modvalue* 800.0)

(defun mod-range (value min max)
  (+ min (mod value max)))

(defun rng (min max)
  "get a random number in range [min max]"
  (let ((range (- max min)))
    (coerce-float (+ min (random (coerce-float range))))))

(defun rng-mod (min max mod-value)
  (mod (rng min max) mod-value))

(veq:vdef point (x y)
  (veq:f2$point (mod x *modvalue*) (mod y *modvalue*)))

(defun rng-pt (min max)
 (point (rng-mod min max *modvalue*) (rng-mod min max *modvalue*)))

(veq:vdef add-pts (pt1 pt2)
  (veq:f2$point
   (veq:f2mod
    (veq:f2$
     (veq:f2$point (veq:f2+ (veq:f2$ pt1) (veq:f2$ pt2))))
   *modvalue*)))

(defun random-elem (xs)
  "Retrieves a random element from a list"
  (nth (random (length xs)) xs))

(veq:vdef shifter (i x y)
  "(x + 1, cos(x + 1) + y)"
  (let ((xo (+ x 100)))
    (veq:f2$point (* 100 (coerce-float xo)) (* 100 (coerce-float (+ (cos xo) y))))))

(veq:vdef spread (pt min max spread-count)
  "Adds random spread to xy with a min/max value
   https://lispcookbook.github.io/cl-cookbook/iteration.html"
  (iter (for i from 0 to spread-count)
        (collect (add-pts pt (rng-pt min max)))))

;(defun spread-mapcan (pts min max spread-count)
;  "Adds random spread to xy with a min/max value"
;  (mapcan (lambda (pt) (spread pt min max spread-count)) pts))

(defun get-iterative-vertex (shifter spread-map spread-count)
  "generates a vertex with shifter and spread-map"
  (lambda (i x y min max)
    (funcall spread-map
             (funcall shifter i x y) min max spread-count)))

(defun get-default-iter-vertex (spread-count)
  (get-iterative-vertex #'shifter #'spread spread-count))

(defparameter *default-iter-vertex* (get-default-iter-vertex 3))

(veq:vdef add-vertex (wer pt1 pt2)
  "Adds an edge and returns the second point"
  ;(vpr pt1 pt2)
  ;(print (f2$ pt1))
  ;(print (f2$ pt2))
  (weir:add-edge! wer
  (weir:2add-vert! wer (veq:f2$ pt1))
  (weir:2add-vert! wer (veq:f2$ pt2))))

(veq:vdef vflatten (pts)
  (mapcan (lambda (p) (veq:fvprogn (veq:f2$ p))) pts))

(defun add-vertices (wer pts)
  (labels ((inner (head tail)
    (let ((head2 (car tail)))
      (if (equal nil head2)
        head
        (progn
          ;(format t "adding ~A ~A ~%" head head2)
          (add-vertex wer head head2)
          ;(print "added sucesfully and recursing")
          (inner head2 (cdr tail)))))))

      (let ((head (car pts)))
        (if (equal nil head)
            nil
            (inner head (cdr pts))))))

(veq:fvdef cos-gen (wer i y min max x-count divisor)
  (let ((ig (/ i divisor))
        (yg y)
        (ming (/ min divisor))
        (maxg (/ max divisor)))

    (labels ((get-new-pts (x) (funcall *default-iter-vertex* ig (/ x divisor) yg ming maxg))
             (add-new-pts (new-pts)
               (progn
                 (add-vertices wer new-pts)
                 (car (last new-pts))))
             (rec-add-pts (x pt)
               (if (< x (+ 1 x-count))
                   (let ((new-pts (cons pt (get-new-pts x))))
                     (progn
              ;(print "adding vertices")
              ;(print new-pts)
              ; (weir:add-path-ind! wer new-pts :closed t)
                       (add-vertices wer new-pts)
              ;(print "vertices added")
                       (rec-add-pts (+ x 1) (add-new-pts new-pts)))))
               nil))
    (rec-add-pts 1 (add-new-pts (get-new-pts 1))))))

(defun cos-gen-ydups (wer i min max x-count y-count divisor)
  (iter (for y from 0 to y-count)
    (cos-gen wer i (+ y 100) min max x-count divisor)))


(veq:vdef* reciprocal-edge-forces (wer &key (stp 0.1))
  (weir:with (wer %)
    ; state of wer is unaltered
    (weir:itr-edges (wer e) ; edge (v0 v1)
      ; vector from v0 to v1
      ; force is proportional to this "oriented distance"
      (veq:f2let ((force (veq:f2-
                           (veq:f2$ (weir:2get-verts wer e)
                                    1 0))))
        (loop for i in e and s in '(-1.0 1.0)
              ; alteration is created, but nothing happens
              do (% (2move-vert? i
                      (veq:f2scale force (* s stp)))))))))


(defun cos-gen-iter (i min max x-count y-count divisor)
  (let ((wer (weir:make :max-verts 1000000))
        (wsvg (wsvg:make*)))
    (progn
      ;; Get ready to make the fans fly
      (gc :full t)
      (cos-gen-ydups wer i min max x-count y-count divisor)
  ; (print (weir:verts wer))
      (weir:2intersect-all! wer)
      (wsvg:path wsvg (weir:verts wer) :fill "gray")
      (weir:itr-verts (wer v)
        (wsvg:circ wsvg 0.10 :xy (veq:lst (weir:2gv wer v)) :fill "black"))
  ; (reciprocal-edge-forces wer)
      (wsvg:save wsvg (concatenate' string "cool" (format nil "~a" i))))))

(defun cos-gen-iters (min max i-count x-count y-count divisor)
  (iter (for i from 0 to i-count)
    (cos-gen-iter i min max x-count y-count divisor)))

(time (cos-gen-iters -25 25 0 20 10 1.5))
