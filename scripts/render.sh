#!/bin/bash

rm $1/*-best.human.dot
ruby scripts/apply_wordmap.rb $1/*.wordmap $1
dot -Tpng $1/*-best.human.dot -o render.png
open render.png
