;--------------------------------------------------------------
; The concept:
;
; 1. Loop through word categories. Set a pointer to the first
; word in a category. 
; 2. While waiting for a key pressed, loop all words. Stop when
;	key pressed. We have now a random word selected.
; 3. User selects a char with UP, DOWN and ENTER keys.
;	The selectkey routine stores the char in a global var.
; 4. A subroutine checks if the char is part of the word.
;	If so, it's added to an array of chars_ok.
;	If not, to chars_fail.
; 5. The display is constantly updated. While printing
;	the word, chars are replaced by dots is the char is not
;	in the array of chars_ok.
;	The chars in char_failed are printed on the second line.
; 6. User wins when no dots are printed.
; 7. User loses if 10 chars are added to chars_fail
;--------------------------------------------------------------


;------------------------------------------
; Constants
;------------------------------------------
PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
DISPLAYSIZE = $38
LINE2START = $28             	; Line 2 starts at character 40 (0x28)
MAXTRY = $8
TRUE = $1
FALSE = $0

E  = %10000000
RW = %01000000
RS = %00100000

KEYA = %00000100
KEYB = %00001000
KEYC = %00010000

EOL = $FF                	; marks end-of-list

;------------------------------------------
; Pointers
;------------------------------------------
msgptr  	= $0000            	; 2 bytes pointer to info msg
wordptr 	= msgptr+$2        	; 2 bytes pointer to selected word
catptr    	= wordptr+$2    	; 2 bytes point to first word of selected category

;------------------------------------------
; Buffers
;------------------------------------------
lastkey 	= $0200            	; 1 byte last pressed key
chartocheck 	= lastkey+$1    	; char to check if correct
display     	= chartocheck+$1	; 56 chars (DISPLAYSIZE) bytes + $00 to display
charsok   	= display+DISPLAYSIZE+$1; MAXTRY (0xA) bytes for chars guessed ok.
charsfail   	= charsok+MAXTRY	; MAXTRY (0xA) bytes for chars guessed wrong.
okcount    	= charsfail+MAXTRY    	; 1 byte holding number of chars in charsok.
failcount	= okcount+1        	; 1 byte holding number of chars in charsfail.
lasttry    	= failcount+1    	; 1 byte holding last tried char
win    	= lasttry+1    	; 1 byte bool indicating if games ends in win

;------------------------------------------
; Start ROM
;------------------------------------------

  .org $8000

reset:
  ldx #$ff
  txs
 
 
  lda #%11111111 	; Set all pins on port B to output
  sta DDRB
  lda #%11100000 	; Set top 3 pins on port A to output
  sta DDRA

  lda #%00111000 	; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001100 	; display on; cursor off; blink off
  jsr lcd_instruction
  lda #%00000110 	; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #$00000001 	; Clear display
  jsr lcd_instruction
 
  jsr select_cat	; Lets user select a category
 
  jsr selectmsg_01	; "Woord aan het kiezen, druk op een toets"
  jsr printmsg
 
newgame:
  lda #$0       	 
  sta okcount       	; Reset okcount
  sta failcount    	; Reset failcount
  sta win           	; Reset win
  lda #"A"
  sta lasttry    	; Reset lasttry
           	 
  jsr randomword	; Select random word  
  ;jsr printword    	; Print selected word
  ;jsr readkey
  jsr selectdisplay	; Select display buffer to display
 
nexttry:
  jsr selectkey    	; Select key, store in lasttry
  lda win
  cmp #TRUE
  beq endwin
  lda lasttry
  sta chartocheck
  jsr charinword
  lda chartocheck	; Read result of check
  beq tryfail    	; Failure?
  jmp tryok
 
tryfail:
  lda lasttry
  ldy failcount
  sta charsfail,y 	; Store in array charsfail
  inc failcount
  lda failcount  
  cmp #MAXTRY
  beq endlost
  jmp nexttry
 
tryok:
  lda lasttry
  ldy okcount
  sta charsok,y    	; Store in array charsok
  inc okcount
  jmp nexttry;
 
endlost:
   jsr selectmsg_03	; "Je bent af"
   jsr printmsg
   jsr readkey    	; Wait for key
   jsr printword    	; Print selected word
   jmp newgame

endwin:
  jsr selectmsg_04	; "Je hebt gewonnen"
  jsr printmsg
  jmp newgame

;------------------------------------------
; Point Wordptr to a random word
; Loops words while waiting for key pressed
;------------------------------------------
randomword:
  pha
  tya                    	; Push y to stack
  pha                    	;  "  "
randomword_loop:
  jsr firstword
randomword_next:
  lda PORTA                    	; readkeys
  and #(KEYA | KEYB | KEYC)
  cmp #(KEYA | KEYB | KEYC)        	; A, B or C pressed?
  bne randomword_end            	; Pressed. Done.

  jsr nextword                    	; Not pressed, next word
  ldy #0                    	; Reached end of list ?
  lda (wordptr),y
  cmp #EOL
  beq randomword_loop              	; EOL, restart
   
  ;jsr printword                	; Print selected word
  jmp randomword_next            	; Not EOL, continue
randomword_end:
  jsr readkey                    	; Wait for key-up
  pla                    	; Pop Y from stack
  tay                    	; "   "
  pla
  rts

;------------------------------------------
; Select key
; Increases okcount
; Adds a char to charsok or charsfail
;------------------------------------------
selectkey:
  pha
  tya            	; Push Y to stack
  pha            	;  "  "
 
selectkey_loop:
  jsr dsp_update     	; Update display with selected word and other info  
  lda win    	; Exit on WIN
  cmp #TRUE
  beq selectkey_enter
  jsr printmsg    	; No win, print display
  jsr readkey        	; wait for key pressed

  lda lastkey
  cmp #"A"   	 
  beq selectkey_up     	; A=up
 
  lda lastkey
  cmp #"B"   	 
  beq selectkey_down	; B=down
 
  lda lastkey
  cmp #"C"   	 
  beq selectkey_enter   ; C=enter
 
  jmp selectkey_loop
selectkey_up:
  lda lasttry
  cmp #"Z"
  beq selectkey_A
  inc lasttry
  jmp selectkey_loop
selectkey_down:
  lda lasttry
  cmp #"A"
  beq selectkey_Z
  dec lasttry
  jmp selectkey_loop
selectkey_A:
  lda #"A"
  sta lasttry
  jmp selectkey_loop
selectkey_Z:
  lda #"Z"
  sta lasttry
  jmp selectkey_loop
selectkey_enter:
  pla            	; Pop Y from stack
  tay            	; "   "
  pla
  rts


;------------------------------------------
; Prints message pointed by msgptr
;------------------------------------------
printmsg:
  pha
  tya            	; Push y to stack
  pha            	;  "  "
  lda #$00000001 	; Clear display
  jsr lcd_instruction
  ldy #0
printmsg_nextchar:
  lda (msgptr),y
  beq printmsg_end
  jsr print_char
  iny
  jmp printmsg_nextchar
printmsg_end:
  pla            	; Pop Y from stack
  tay            	; "   "
  pla
  rts

;------------------------------------------
; Prints the selected word
;------------------------------------------
printword:
  pha
  tya            	; Push y to stack
  pha            	;  "  "
 
  lda #$00000001     	; Clear display
  jsr lcd_instruction
  ldy #0
printword_nextchar:
  lda (wordptr),y
  beq printword_end
  jsr print_char
  iny
  jmp printword_nextchar
printword_end:
  pla            	; Pop Y from stack
  tay            	; "   "
  pla
  rts

;------------------------------------------
; Point MsgPtr to Message 01
; "Woord aan het kiezen, druk op een toets"
;------------------------------------------
selectmsg_01:
  pha
  lda #<msg_01
  sta msgptr
  lda #>msg_01
  sta msgptr+1
  pla
  rts

;------------------------------------------
; Point MsgPtr to Message 02
; "Raad een automerk"
;------------------------------------------
selectmsg_02:
  pha
  lda #<msg_02
  sta msgptr
  lda #>msg_02
  sta msgptr+1
  pla
  rts
 
;------------------------------------------
; Point MsgPtr to Message 03
; "Je hebt verloren"
;------------------------------------------
selectmsg_03:
  pha
  lda #<msg_03
  sta msgptr
  lda #>msg_03
  sta msgptr+1
  pla
  rts

;------------------------------------------
; Point MsgPtr to Message 04
; "Je hebt het geraden"
;------------------------------------------
selectmsg_04:
  pha
  lda #<msg_04
  sta msgptr
  lda #>msg_04
  sta msgptr+1
  pla
  rts

;------------------------------------------
; Point MsgPtr to Message 05
; "Raad een kort Nederlands woord"
;------------------------------------------
selectmsg_05:
  pha
  lda #<msg_05
  sta msgptr
  lda #>msg_05
  sta msgptr+1
  pla
  rts
 
;------------------------------------------
; Point MsgPtr to Message 06
; "Raad een lang Nederlands woord"
;------------------------------------------
selectmsg_06:
  pha
  lda #<msg_06
  sta msgptr
  lda #>msg_06
  sta msgptr+1
  pla
  rts
 
;------------------------------------------
; Point MsgPtr to Message 07
; "Raad een babynamen top 100"
;------------------------------------------
selectmsg_07:
  pha
  lda #<msg_07
  sta msgptr
  lda #>msg_07
  sta msgptr+1
  pla
  rts
 
;------------------------------------------
; Point MsgPtr to Message 08
; "Raad een Nederlandse stad"
;------------------------------------------
selectmsg_08:
  pha
  lda #<msg_08
  sta msgptr
  lda #>msg_08
  sta msgptr+1
  pla
  rts
 
;------------------------------------------
; Point MsgPtr to Message 09
; "Raad een Engels woord"
;------------------------------------------
selectmsg_09:
  pha
  lda #<msg_09
  sta msgptr
  lda #>msg_09
  sta msgptr+1
  pla
  rts
 
 
;------------------------------------------
; Point MsgPtr to display
;------------------------------------------
selectdisplay:
  pha
  ;set msgptr to display
  lda #<display
  sta msgptr
  lda #>display
  sta msgptr+1
  pla
  rts

;------------------------------------------
; Point catptr to selected category
;------------------------------------------  
select_cat:
  pha

select_cat1:    	; Category 1 words
  jsr selectmsg_02    
  jsr printmsg
  jsr readkey
  lda lastkey  
  cmp #"C"    	; C = Enter, A/B = Next category
  bne select_cat2	; Next category
 
  lda #<words_cars
  sta catptr
  lda #>words_cars
  sta catptr+1
  jmp select_cat_done    

select_cat2:    	; Category 2 words
  jsr selectmsg_05    
  jsr printmsg
  jsr readkey
  lda lastkey  
  cmp #"C"    	; C = Enter, A/B = Next category
  bne select_cat3	; Next category

  lda #<words_nl_short
  sta catptr
  lda #>words_nl_short
  sta catptr+1
  jmp select_cat_done

select_cat3:
  jsr selectmsg_06    
  jsr printmsg
  jsr readkey
  lda lastkey  
  cmp #"C"    	; C = Enter, A/B = Next category
  bne select_cat4	; Next category

  lda #<words_nl_long
  sta catptr
  lda #>words_nl_long
  sta catptr+1
  jmp select_cat_done
 
select_cat4:
  jsr selectmsg_07    
  jsr printmsg
  jsr readkey
  lda lastkey  
  cmp #"C"    	; C = Enter, A/B = Next category
  bne select_cat5	; Next category

  lda #<words_baby100
  sta catptr
  lda #>words_baby100
  sta catptr+1
  jmp select_cat_done
 
select_cat5:
  jsr selectmsg_08    
  jsr printmsg
  jsr readkey
  lda lastkey  
  cmp #"C"    	; C = Enter, A/B = Next category
  bne select_cat6	; Next category

  lda #<words_city_nl
  sta catptr
  lda #>words_city_nl
  sta catptr+1
  jmp select_cat_done  

select_cat6:
  jsr selectmsg_09    
  jsr printmsg
  jsr readkey
  lda lastkey  
  cmp #"C"    	; C = Enter, A/B = Next category
  bne select_cat7	; Next category

  lda #<words_english
  sta catptr
  lda #>words_english
  sta catptr+1
  jmp select_cat_done  

select_cat7:
  jmp select_cat1
select_cat_done:
  pla
  rts

;------------------------------------------
; Point Wordptr to first Word
;------------------------------------------  
firstword:
  pha
  lda catptr
  sta wordptr
  lda catptr+1
  sta wordptr+1
  pla
  rts

;------------------------------------------
; Point Wordptr to next Word
;------------------------------------------  
nextword:
  pha
  tya            	; Push y to stack
  pha            	;  "  "
nextword_loop:
  ldy #0        	;check if char is end of string ($00)
  lda (wordptr),y
  beq nextword_end    	;if 00 we found end of string
 
  jsr incwordptr    	;step to next char
  jmp nextword_loop    	;loop
nextword_end:        	;we found end of string
  jsr incwordptr    	;step past last char ($00), so we are at the start of next string
  pla            	; Pop Y from stack
  tay            	; "   "
  pla
  rts
 
;------------------------------------------
; Increments wordptr (pointer to Words)
;------------------------------------------  
incwordptr:
  pha
  inc wordptr
  bne nooverflow
  inc wordptr + 1
nooverflow:
  pla
  rts

;------------------------------------------
; Wait for key
; Stores pressed key to $lastkey
; Keys: "A", "B" or "C"
;------------------------------------------
readkey:
  pha
waitkey:
  lda PORTA
  and #KEYA
  beq a_pressed 	; Button A pressed
  lda PORTA
  and #KEYB
  beq b_pressed 	; Button B pressed
  lda PORTA
  and #KEYC
  beq c_pressed 	; Button C pressed
  jmp waitkey
a_pressed:
  lda #"A"
  jmp readkey_done
b_pressed:
  lda #"B"
  jmp readkey_done
c_pressed:
  lda #"C"
  jmp readkey_done
readkey_done:
  sta lastkey  
  ;jsr print_char
  ;wait for release
keydown:          	; loop while key is still down
  lda PORTA
  and #(KEYA | KEYB | KEYC)
  cmp #(KEYA | KEYB | KEYC)
  bne keydown    
  pla
  rts
 
;------------------------------------------
; Waits for LCD Display ready
;------------------------------------------
lcd_wait:
  pha
  lda #%00000000  ; Port B is input
  sta DDRB
lcdbusy:
  lda #RW
  sta PORTA
  lda #(RW | E)
  sta PORTA
  lda PORTB
  and #%10000000
  bne lcdbusy

  lda #RW
  sta PORTA
  lda #%11111111  ; Port B is output
  sta DDRB
  pla
  rts

;------------------------------------------
; Toggles LCD display Enable
;------------------------------------------
lcd_instruction:
  pha
  jsr lcd_wait
  sta PORTB
  lda #0     	; Clear RS/RW/E bits
  sta PORTA
  lda #E     	; Set E bit to send instruction
  sta PORTA
  lda #0     	; Clear RS/RW/E bits
  sta PORTA
  pla
  rts

;------------------------------------------
; Prints a single char (A) to display
;------------------------------------------
print_char:
  jsr lcd_wait
  sta PORTB
  lda #RS     	; Set RS; Clear RW/E bits
  sta PORTA
  lda #(RS | E)   ; Set E bit to send instruction
  sta PORTA
  lda #RS     	; Clear E bits
  sta PORTA
  rts

;------------------------------------------
; Rebuilds the Display memory
; store at $(display)
;------------------------------------------
dsp_update:
  pha
  tya            	; Push y to stack
  pha            	;  "  "
 
  lda #TRUE
  sta win    	; Assume user wins, store FALSE on wrong char
  ldy #0
 
; Display dot or char for each char
; Fill remaining Line 1 with spaces
; Y = 0 (top left)
dsp_update_nextdot:   	 
  lda (wordptr),y
  beq dsp_update_fill_L1	; Found end of string of word?, fill Line 1
  sta chartocheck        	; Save to $chartocheck, so subroutine will check
  jsr charincharsok        	; Updates $chartocheck to 1 (correct) or 0 (fail)
  lda chartocheck        	; Load result    
  beq dsp_update_fail
  lda (wordptr),y    	; end of word?
  jmp dsp_update_checked
dsp_update_fail:  
  lda #FALSE
  sta win        	; not winning yet
  lda #%10100101      	; center point char
dsp_update_checked:  
  sta display,y          	; copy '.' or char to display buffer
  iny
  jmp dsp_update_nextdot
dsp_update_fill_L1:        	; fill remaining Line 1 with blanks
  cpy #LINE2START        	; Is y at first char of Line 2?
  beq dsp_update_tried  	; done, Line 1, start Line 2
  lda #" "
  sta display,y          	; copy ' ' for each char in word,to display buffer
  iny
  jmp dsp_update_fill_L1	; Keep filling Line 1

; Display charsfail tried
; Y = Line2, First position
dsp_update_tried:       	 
  ldx failcount 	 
  beq dsp_update_post_chars    	; Nothing? Add questionmark
dsp_update_chars:  
  dex            	; x = okcount -1 (position in array)
  lda charsfail,x
  sta display,y    
  iny            	; Move cursor right
  cpx #$0        	; End of loop? Add questionmark
  beq dsp_update_post_chars   	 
  jmp dsp_update_chars

; Y is Line2, after last char failed
; Add * for each try available
dsp_update_post_chars
  lda #"_"
  ldx failcount 	 
dsp_update_post_chars_loop
  cpx #MAXTRY
  beq dsp_update_qmark
  sta display,y
  inx
  iny
  jmp dsp_update_post_chars_loop

; Y is Line2, after last *
; Inserts "?" and lasttry
dsp_update_qmark:       	 
  lda #"?"
  sta display,y       	 
  iny
  lda lasttry
  sta display,y
  iny
dsp_update_end
  lda #$00            	; always end string with 00
  sta display,y
 
  pla                	; Pop Y from stack
  tay                	; "   "
  pla
  rts

;------------------------------------------
; checks if chartocheck exists in the
; charsok array overwrites $chartocheck
; with 1 (found) or 0 (not found)
;------------------------------------------
charincharsok:
  pha
  tya                	; transfer current y to a
  pha                	; push to stack
 
  ldy #0              	; Pointer to char to check in chars
  lda okcount            	; check if empty
  beq charincharsok_not_found	; No more to try: not found
charincharsok_next:        	; Check one char
  lda charsok,y
  cmp chartocheck        	; Compare with char to check
  beq charincharsok_found
  eor #%00100000         	; XOR A with 100000 swaps Upper/Lower case
  cmp chartocheck        	; Compare with char to check
  beq charincharsok_found  
  iny
  cpy okcount
  beq charincharsok_not_found	; No more to try: not found
  jmp charincharsok_next
charincharsok_found:
  lda #TRUE
  sta chartocheck
  jmp charincharsok_done
charincharsok_not_found:
  lda #FALSE
  sta chartocheck
charincharsok_done
  pla                	; pop from to stack
  tay                	; transfer current a to y
  pla
  rts
 
;------------------------------------------
; checks if chartocheck exists in the word
; array overwrites chartocheck with
; 1 (found) or 0 (not found)
;------------------------------------------
charinword:
  pha
  tya                	; transfer current y to a
  pha                	; push to stack
 
  ldy #0              	; Pointer to char to check in chars
charinword_next:           	; Check one char
  lda (wordptr),y
  cmp chartocheck        	; Compare with char to check
  beq charinword_found
  eor #%00100000         	; XOR A with 100000 swaps Upper/Lower case
  cmp chartocheck        	; Compare with char to check
  beq charinword_found  
  iny            	; Next char in Word
  lda (wordptr),y    	; Reached end?
  beq charinword_not_found
  jmp charinword_next
charinword_found:
  lda #TRUE
  sta chartocheck
  jmp charinword_done
charinword_not_found:
  lda #FALSE
  sta chartocheck
charinword_done
  pla                	; pop from to stack
  tay                	; transfer current a to y
  pla
  rts
 
end:
  jmp end

;------------------------------------------
; Message strings
;------------------------------------------
;              	[.....Line1....]                    	[.....Line2....]
msg_01: .asciiz "Woord zoeken....                    	Stoppen? (druk)"
msg_02: .asciiz "Automerk                            	A/B=Vlgn C=Kies"
msg_03: .asciiz "Je bent af!                         	Zien?"
msg_04: .asciiz "Yes! Je hebt                        	het geraden!"
msg_05: .asciiz "Kort woord (NL)                     	A/B=Vlgn C=Kies"
msg_06: .asciiz "Lang woord (NL)                     	A/B=Vlgn C=Kies"
msg_07: .asciiz "Babynamen Top100                    	A/B=Vlgn C=Kies"
msg_08: .asciiz "Nederlandse Stad                    	A/B=Vlgn C=Kies"
msg_09: .asciiz "Engels woord                        	A/B=Vlgn C=Kies"
;------------------------------------------
; Words
;------------------------------------------
;      	[.MAX 16 char..]
words_cars:
  .asciiz "Toyota"
  .asciiz "Tesla"
  .asciiz "BMW"
  .asciiz "Volkswagen"
  .asciiz "Ford"
  .asciiz "Nissan"
  .asciiz "Mercedes"
  .asciiz "Audi"
  .asciiz "Mazda"
  .asciiz "Cadillac"
  .asciiz "Chevrolet"
  .asciiz "Bugatti"
  .asciiz "Lamborghini"
  .asciiz "Skoda"
  .asciiz "Kia"
  .asciiz "Mini"
  .asciiz "Saab"
  .asciiz "Volvo"
  .asciiz "Landrover"
  .asciiz "Jaguar"
  .asciiz "Jeep"
  .asciiz "Honda"
  .asciiz "Ferrari"
  .asciiz "Hummer"
  .asciiz "Kia"
  .asciiz "Lexus"
  .asciiz "Opel"
  .asciiz "Seat"
  .asciiz "Smart"
  .asciiz "Renault"
  .asciiz "Porsche"
  .asciiz "Peugeot"
  .asciiz "Mitsubishi"
  .asciiz "Maserati"
  .asciiz "Bentley"
  .asciiz "Dacia"
  .asciiz "DAF"
  .asciiz "Lancia"
  .asciiz "Suzuki"
  .asciiz "Subaru"
  .word EOL
;      	[.MAX 16 char..]
words_nl_short:
  .asciiz "Cavia"
  .asciiz "Krukje"
  .asciiz "Tijd"
  .asciiz "Fors"
  .asciiz "Sambal"
  .asciiz "Zuivel"
  .asciiz "Kritisch"
  .asciiz "Jasje"
  .asciiz "Giga"
  .asciiz "Dieren"
  .asciiz "Lepel"
  .asciiz "Picknick"
  .asciiz "Quasi"
  .asciiz "Verzenden"
  .asciiz "Winnaar"
  .asciiz "Dextrose"
  .asciiz "Vrezen"
  .asciiz "Niqaab"
  .asciiz "Hierbij"
  .asciiz "Quote"
  .asciiz "Botox"
  .asciiz "Cruciaal"
  .asciiz "Zitting"
  .asciiz "Cabaret"
  .asciiz "Bewogen"
  .asciiz "Vrijuit"
  .asciiz "Carriere"
  .asciiz "IJverig"
  .asciiz "Cake"
  .asciiz "Dyslexie"
  .asciiz "Uier"
  .asciiz "Nihil"
  .asciiz "Sausje"
  .asciiz "Kuuroord"
  .asciiz "Poppetje"
  .asciiz "Docent"
  .asciiz "Camping"
  .asciiz "Schijn"
  .asciiz "Kloppen"
  .asciiz "Detox"
  .asciiz "Boycot"
  .asciiz "Cyclus"
  .asciiz "Quiz"
  .asciiz "Censuur"
  .asciiz "Aaibaar"
  .asciiz "Fictief"
  .asciiz "Chef"
  .asciiz "Gering"
  .asciiz "Nacht"
  .asciiz "Cacao"
  .asciiz "Triomf"
  .asciiz "Baby"
  .asciiz "IJstijd"
  .asciiz "Cruisen"
  .asciiz "Ontzeggen"
  .asciiz "Quad"
  .asciiz "Open"
  .asciiz "Turquoise"
  .asciiz "Carnaval"
  .asciiz "Boxer"
  .asciiz "Straks"
  .asciiz "Fysiek"
  .asciiz "Accu"
  .asciiz "Twijg"
  .asciiz "Quote"
  .asciiz "Gammel"
  .asciiz "Flirt"
  .asciiz "Futloos"
  .asciiz "Vreugde"
  .asciiz "Ogen"
  .asciiz "Geloof"
  .asciiz "Periode"
  .asciiz "Uitleg"
  .asciiz "Stuk"
  .asciiz "Volk"
  .asciiz "Even"
  .asciiz "Stijl"
  .asciiz "Val"
  .asciiz "Tocht"
  .asciiz "Mooi"
  .asciiz "Joggen"
  .asciiz "Broek"
  .asciiz "Kwik"
  .asciiz "Werksfeer"
  .asciiz "Vorm"
  .asciiz "Nieuw"
  .asciiz "Sopraan"
  .asciiz "Miljoen"
  .asciiz "Klacht"
  .asciiz "Dak"
  .asciiz "Echt"
  .asciiz "Schikking"
  .asciiz "Print"
  .asciiz "Oorlog"
  .asciiz "Zijraam"
  .asciiz "Hyacint"
  .word EOL

;      	[.MAX 16 char..]
words_nl_long:
  .asciiz "Koningskind"
  .asciiz "Radicalisering"
  .asciiz "Parfumeriezaak"
  .asciiz "Historicus"
  .asciiz "Ruitensproeier"
  .asciiz "Gehandicapten"
  .asciiz "Migratieroute"
  .asciiz "Bouwkundige"
  .asciiz "Dromedarissen"
  .asciiz "Bergbeklimmer"
  .asciiz "Alliantie"
  .asciiz "Goedgemutst"
  .asciiz "Inrichting"
  .asciiz "Cappuccino"
  .asciiz "Pyjamabroek"
  .asciiz "Zenuwinzinking"
  .asciiz "Chagrijnig"
  .asciiz "Pedagogisch"
  .asciiz "Beenmergpunctie"
  .asciiz "Volwaardig"
  .asciiz "Zuivelproduct"
  .asciiz "Geluidstechnicus"
  .asciiz "Gedragstherapeut"
  .asciiz "Waterbouwkundige"
  .asciiz "Vastgoedmakelaar"
  .asciiz "Schoorsteenveger"
  .asciiz "Theaterproducent"
  .asciiz "Radiopresentator"
  .asciiz "Paardenhandelaar"
  .asciiz "Vuurtorenwachter"
  .word EOL

;      	[.MAX 16 char..]
words_baby100:
  .asciiz "Noah"
  .asciiz "Emma"
  .asciiz "Liam"
  .asciiz "Luca"
  .asciiz "Julia"
  .asciiz "Lucas"
  .asciiz "Mila"
  .asciiz "Mees"
  .asciiz "Sophie"
  .asciiz "Finn"
  .asciiz "James"
  .asciiz "Mila"
  .asciiz "Olivia"
  .asciiz "Levi"
  .asciiz "Sem"
  .asciiz "Sam"
  .asciiz "Yara"
  .asciiz "Daan"
  .asciiz "Noud"
  .asciiz "Saar"
  .asciiz "Nora"
  .asciiz "Luuk"
  .asciiz "Tess"
  .asciiz "Adam"
  .asciiz "Noor"
  .asciiz "Milou"
  .asciiz "Sara"
  .asciiz "Liv"
  .asciiz "Zoë"
  .asciiz "Bram"
  .asciiz "Evi"
  .asciiz "Anna"
  .asciiz "Luna"
  .asciiz "Zayn"
  .asciiz "Mason"
  .asciiz "Lotte"
  .asciiz "Nina"
  .asciiz "Benjamin"
  .asciiz "Eva"
  .asciiz "Emily"
  .asciiz "Lauren"
  .asciiz "Maeve"
  .asciiz "Lina"
  .asciiz "Elin"
  .asciiz "Isa"
  .asciiz "Boaz"
  .asciiz "Maud"
  .asciiz "Siem"
  .asciiz "Guus"
  .asciiz "Morris"
  .asciiz "Sarah"
  .asciiz "Olivier"
  .asciiz "Thomas"
  .asciiz "Teun"
  .asciiz "Nova"
  .asciiz "Loïs"
  .asciiz "Sofia"
  .asciiz "Mia"
  .asciiz "Gijs"
  .asciiz "Mats"
  .asciiz "Sofie"
  .asciiz "Lieke"
  .asciiz "Fleur"
  .asciiz "Max"
  .asciiz "Fien"
  .asciiz "Lynn"
  .asciiz "Jesse"
  .asciiz "Julian"
  .asciiz "Otis"
  .asciiz "Floris"
  .asciiz "Hailey"
  .asciiz "Lars"
  .asciiz "Bo"
  .asciiz "David"
  .asciiz "Jake"
  .asciiz "Moos"
  .asciiz "Rayan"
  .asciiz "Roos"
  .asciiz "Jens"
  .asciiz "Julie"
  .asciiz "Joep"
  .asciiz "Livia"
  .asciiz "Owen"
  .asciiz "Fenna"
  .asciiz "Jip"
  .asciiz "Ella"
  .asciiz "Lou"
  .asciiz "Sophia"
  .asciiz "Thijs"
  .asciiz "Jan"
  .asciiz "Oliver"
  .asciiz "Willem"
  .asciiz "Charlie"
  .asciiz "Mick"
  .asciiz "Jack"
  .asciiz "Jurre"
  .asciiz "Noa"
  .asciiz "Abel"
  .asciiz "Kai"
  .asciiz "Lily"
  .word EOL

;      	[.MAX 16 char..]
words_city_nl:
  .asciiz "Amsterdam"
  .asciiz "Rotterdam"
  .asciiz "Utrecht"
  .asciiz "Eindhoven"
  .asciiz "Groningen"
  .asciiz "Tilburg"
  .asciiz "Almere"
  .asciiz "Breda"
  .asciiz "Nijmegen"
  .asciiz "Apeldoorn"
  .asciiz "Haarlem"
  .asciiz "Arnhem"
  .asciiz "Haarlemmermeer"
  .asciiz "Amersfoort"
  .asciiz "Enschede"
  .asciiz "Zaanstad"
  .asciiz "Zwolle"
  .asciiz "Leiden"
  .asciiz "Leeuwarden"
  .asciiz "Zoetermeer"
  .asciiz "Maastricht"
  .asciiz "Ede"
  .asciiz "Dordrecht"
  .asciiz "Westland"
  .asciiz "Alkmaar"
  .asciiz "Delft"
  .asciiz "Emmen"
  .asciiz "Venlo"
  .asciiz "Deventer"
  .asciiz "Someren"
  .word EOL


;      	[.MAX 16 char..]
words_english:
  .asciiz "Able"
  .asciiz "About"
  .asciiz "Account"
  .asciiz "Acid"
  .asciiz "Across"
  .asciiz "Act"
  .asciiz "Addition"
  .asciiz "Adjustment"
  .asciiz "Advertisement"
  .asciiz "After"
  .asciiz "Again"
  .asciiz "Against"
  .asciiz "Agreement"
  .asciiz "Air"
  .asciiz "All"
  .asciiz "Almost"
  .asciiz "Among"
  .asciiz "Amount"
  .asciiz "Amusement"
  .asciiz "And"
  .asciiz "Angle"
  .asciiz "Angry"
  .asciiz "Animal"
  .asciiz "Answer"
  .asciiz "Ant"
  .asciiz "Any"
  .asciiz "Apple"
  .asciiz "Approval"
  .asciiz "Arch"
  .asciiz "Argument"
  .asciiz "Arm"
  .asciiz "Army"
  .asciiz "Art"
  .asciiz "As"
  .asciiz "At"
  .asciiz "Attack"
  .asciiz "Attempt"
  .asciiz "Attention"
  .asciiz "Attraction"
  .asciiz "Authority"
  .asciiz "Automatic"
  .asciiz "Awake"
  .asciiz "Baby"
  .asciiz "Back"
  .asciiz "Bad"
  .asciiz "Bag"
  .asciiz "Balance"
  .asciiz "Ball"
  .asciiz "Band"
  .asciiz "Base"
  .asciiz "Basin"
  .asciiz "Basket"
  .asciiz "Bath"
  .asciiz "Be"
  .asciiz "Beautiful"
  .asciiz "Because"
  .asciiz "Bed"
  .asciiz "Bee"
  .asciiz "Before"
  .asciiz "Behaviour"
  .asciiz "Belief"
  .asciiz "Bell"
  .asciiz "Bent"
  .asciiz "Berry"
  .asciiz "Between"
  .asciiz "Bird"
  .asciiz "Birth"
  .asciiz "Bit"
  .asciiz "Bite"
  .asciiz "Bitter"
  .asciiz "Black"
  .asciiz "Blade"
  .asciiz "Blood"
  .asciiz "Blow"
  .asciiz "Blue"
  .asciiz "Board"
  .asciiz "Boat"
  .asciiz "Body"
  .asciiz "Boiling"
  .asciiz "Bone"
  .asciiz "Book"
  .asciiz "Boot"
  .asciiz "Bottle"
  .asciiz "Box"
  .asciiz "Boy"
  .asciiz "Brain"
  .asciiz "Brake"
  .asciiz "Branch"
  .asciiz "Brass"
  .asciiz "Bread"
  .asciiz "Breath"
  .asciiz "Brick"
  .asciiz "Bridge"
  .asciiz "Bright"
  .asciiz "Broken"
  .asciiz "Brother"
  .asciiz "Brown"
  .asciiz "Brush"
  .asciiz "Bucket"
  .asciiz "Building"
  .asciiz "Bulb"
  .asciiz "Burn"
  .asciiz "Burst"
  .asciiz "Business"
  .asciiz "But"
  .asciiz "Butter"
  .asciiz "Button"
  .asciiz "By"
  .asciiz "Cake"
  .asciiz "Camera"
  .asciiz "Canvas"
  .asciiz "Card"
  .asciiz "Care"
  .asciiz "Carriage"
  .asciiz "Cart"
  .asciiz "Cat"
  .asciiz "Cause"
  .asciiz "Certain"
  .asciiz "Chain"
  .asciiz "Chalk"
  .asciiz "Chance"
  .asciiz "Change"
  .asciiz "Cheap"
  .asciiz "Cheese"
  .asciiz "Chemical"
  .asciiz "Chest"
  .asciiz "Chief"
  .asciiz "Chin"
  .asciiz "Church"
  .asciiz "Circle"
  .asciiz "Clean"
  .asciiz "Clear"
  .asciiz "Clock"
  .asciiz "Cloth"
  .asciiz "Cloud"
  .asciiz "Coal"
  .asciiz "Coat"
  .asciiz "Cold"
  .asciiz "Collar"
  .asciiz "Colour"
  .asciiz "Comb"
  .asciiz "Come"
  .asciiz "Comfort"
  .asciiz "Committee"
  .asciiz "Common"
  .asciiz "Company"
  .asciiz "Comparison"
  .asciiz "Competition"
  .asciiz "Complete"
  .asciiz "Complex"
  .asciiz "Condition"
  .asciiz "Connection"
  .asciiz "Conscious"
  .asciiz "Control"
  .asciiz "Cook"
  .asciiz "Copper"
  .asciiz "Copy"
  .asciiz "Cord"
  .asciiz "Cork"
  .asciiz "Cotton"
  .asciiz "Cough"
  .asciiz "Country"
  .asciiz "Cover"
  .asciiz "Cow"
  .asciiz "Crack"
  .asciiz "Credit"
  .asciiz "Crime"
  .asciiz "Cruel"
  .asciiz "Crush"
  .asciiz "Cry"
  .asciiz "Cup"
  .asciiz "Cup"
  .asciiz "Current"
  .asciiz "Curtain"
  .asciiz "Curve"
  .asciiz "Cushion"
  .asciiz "Damage"
  .asciiz "Danger"
  .asciiz "Dark"
  .asciiz "Daughter"
  .asciiz "Day"
  .asciiz "Dead"
  .asciiz "Dear"
  .asciiz "Death"
  .asciiz "Debt"
  .asciiz "Decision"
  .asciiz "Deep"
  .asciiz "Degree"
  .asciiz "Delicate"
  .asciiz "Dependent"
  .asciiz "Design"
  .asciiz "Desire"
  .asciiz "Destruction"
  .asciiz "Detail"
  .asciiz "Development"
  .asciiz "Different"
  .asciiz "Digestion"
  .asciiz "Direction"
  .asciiz "Dirty"
  .asciiz "Discovery"
  .asciiz "Discussion"
  .asciiz "Disease"
  .asciiz "Disgust"
  .asciiz "Distance"
  .asciiz "Distribution"
  .asciiz "Division"
  .asciiz "Do"
  .asciiz "Dog"
  .asciiz "Door"
  .asciiz "Doubt"
  .asciiz "Down"
  .asciiz "Drain"
  .asciiz "Drawer"
  .asciiz "Dress"
  .asciiz "Drink"
  .asciiz "Driving"
  .asciiz "Drop"
  .asciiz "Dry"
  .asciiz "Dust"
  .asciiz "Ear"
  .asciiz "Early"
  .asciiz "Earth"
  .asciiz "East"
  .asciiz "Edge"
  .asciiz "Education"
  .asciiz "Effect"
  .asciiz "Egg"
  .asciiz "Elastic"
  .asciiz "Electric"
  .asciiz "End"
  .asciiz "Engine"
  .asciiz "Enough"
  .asciiz "Equal"
  .asciiz "Error"
  .asciiz "Even"
  .asciiz "Event"
  .asciiz "Ever"
  .asciiz "Every"
  .asciiz "Example"
  .asciiz "Exchange"
  .asciiz "Existence"
  .asciiz "Expansion"
  .asciiz "Experience"
  .asciiz "Expert"
  .asciiz "Eye"
  .asciiz "Face"
  .asciiz "Fact"
  .asciiz "Fall"
  .asciiz "False"
  .asciiz "Family"
  .asciiz "Far"
  .asciiz "Farm"
  .asciiz "Fat"
  .asciiz "Father"
  .asciiz "Fear"
  .asciiz "Feather"
  .asciiz "Feeble"
  .asciiz "Feeling"
  .asciiz "Female"
  .asciiz "Fertile"
  .asciiz "Fiction"
  .asciiz "Field"
  .asciiz "Fight"
  .asciiz "Finger"
  .asciiz "Fire"
  .asciiz "First"
  .asciiz "Fish"
  .asciiz "Fixed"
  .asciiz "Flag"
  .asciiz "Flame"
  .asciiz "Flat"
  .asciiz "Flight"
  .asciiz "Floor"
  .asciiz "Flower"
  .asciiz "Fly"
  .asciiz "Fold"
  .asciiz "Food"
  .asciiz "Foolish"
  .asciiz "Foot"
  .asciiz "For"
  .asciiz "Force"
  .asciiz "Fork"
  .asciiz "Form"
  .asciiz "Forward"
  .asciiz "Fowl"
  .asciiz "Frame"
  .asciiz "Free"
  .asciiz "Frequent"
  .asciiz "Friend"
  .asciiz "From"
  .asciiz "Front"
  .asciiz "Fruit"
  .asciiz "Full"
  .asciiz "Future"
  .asciiz "Garden"
  .asciiz "General"
  .asciiz "Get"
  .asciiz "Girl"
  .asciiz "Give"
  .asciiz "Glass"
  .asciiz "Glove"
  .asciiz "Go"
  .asciiz "Goat"
  .asciiz "Gold"
  .asciiz "Good"
  .asciiz "Government"
  .asciiz "Grain"
  .asciiz "Grass"
  .asciiz "Great"
  .asciiz "Green"
  .asciiz "Grey"
  .asciiz "Grip"
  .asciiz "Group"
  .asciiz "Growth"
  .asciiz "Guide"
  .asciiz "Gun"
  .asciiz "Hair"
  .asciiz "Hammer"
  .asciiz "Hand"
  .asciiz "Hanging"
  .asciiz "Happy"
  .asciiz "Harbour"
  .asciiz "Hard"
  .asciiz "Harmony"
  .asciiz "Hat"
  .asciiz "Hate"
  .asciiz "Have"
  .asciiz "He"
  .asciiz "Head"
  .asciiz "Healthy"
  .asciiz "Hear"
  .asciiz "Hearing"
  .asciiz "Heart"
  .asciiz "Heat"
  .asciiz "Help"
  .asciiz "High"
  .asciiz "History"
  .asciiz "Hole"
  .asciiz "Hollow"
  .asciiz "Hook"
  .asciiz "Hope"
  .asciiz "Horn"
  .asciiz "Horse"
  .asciiz "Hospital"
  .asciiz "Hour"
  .asciiz "House"
  .asciiz "How"
  .asciiz "Humour"
  .asciiz "I"
  .asciiz "Ice"
  .asciiz "Idea"
  .asciiz "If"
  .asciiz "Ill"
  .asciiz "Important"
  .asciiz "Impulse"
  .asciiz "In"
  .asciiz "Increase"
  .asciiz "Industry"
  .asciiz "Ink"
  .asciiz "Insect"
  .asciiz "Instrument"
  .asciiz "Insurance"
  .asciiz "Interest"
  .asciiz "Invention"
  .asciiz "Iron"
  .asciiz "Island"
  .asciiz "Jelly"
  .asciiz "Jewel"
  .asciiz "Join"
  .asciiz "Journey"
  .asciiz "Judge"
  .asciiz "Jump"
  .asciiz "Keep"
  .asciiz "Kettle"
  .asciiz "Key"
  .asciiz "Kick"
  .asciiz "Kind"
  .asciiz "Kiss"
  .asciiz "Knee"
  .asciiz "Knife"
  .asciiz "Knot"
  .asciiz "Knowledge"
  .asciiz "Land"
  .asciiz "Language"
  .asciiz "Last"
  .asciiz "Late"
  .asciiz "Laugh"
  .asciiz "Law"
  .asciiz "Lead"
  .asciiz "Leaf"
  .asciiz "Learning"
  .asciiz "Leather"
  .asciiz "Left"
  .asciiz "Leg"
  .asciiz "Let"
  .asciiz "Letter"
  .asciiz "Level"
  .asciiz "Library"
  .asciiz "Lift"
  .asciiz "Light"
  .asciiz "Like"
  .asciiz "Limit"
  .asciiz "Line"
  .asciiz "Linen"
  .asciiz "Lip"
  .asciiz "Liquid"
  .asciiz "List"
  .asciiz "Little"
  .asciiz "Living"
  .asciiz "Lock"
  .asciiz "Long"
  .asciiz "Look"
  .asciiz "Loose"
  .asciiz "Loss"
  .asciiz "Loud"
  .asciiz "Love"
  .asciiz "Low"
  .asciiz "Machine"
  .asciiz "Make"
  .asciiz "Male"
  .asciiz "Man"
  .asciiz "Manager"
  .asciiz "Map"
  .asciiz "Mark"
  .asciiz "Market"
  .asciiz "Married"
  .asciiz "Mass"
  .asciiz "Match"
  .asciiz "Material"
  .asciiz "May"
  .asciiz "Meal"
  .asciiz "Measure"
  .asciiz "Meat"
  .asciiz "Medical"
  .asciiz "Meeting"
  .asciiz "Memory"
  .asciiz "Metal"
  .asciiz "Middle"
  .asciiz "Military"
  .asciiz "Milk"
  .asciiz "Mind"
  .asciiz "Mine"
  .asciiz "Minute"
  .asciiz "Mist"
  .asciiz "Mixed"
  .asciiz "Money"
  .asciiz "Monkey"
  .asciiz "Month"
  .asciiz "Moon"
  .asciiz "Morning"
  .asciiz "Mother"
  .asciiz "Motion"
  .asciiz "Mountain"
  .asciiz "Mouth"
  .asciiz "Move"
  .asciiz "Much"
  .asciiz "Muscle"
  .asciiz "Music"
  .asciiz "Nail"
  .asciiz "Name"
  .asciiz "Narrow"
  .asciiz "Nation"
  .asciiz "Natural"
  .asciiz "Near"
  .asciiz "Necessary"
  .asciiz "Neck"
  .asciiz "Need"
  .asciiz "Needle"
  .asciiz "Nerve"
  .asciiz "Net"
  .asciiz "New"
  .asciiz "News"
  .asciiz "Night"
  .asciiz "No"
  .asciiz "Noise"
  .asciiz "Normal"
  .asciiz "North"
  .asciiz "Nose"
  .asciiz "Not"
  .asciiz "Note"
  .asciiz "Now"
  .asciiz "Number"
  .asciiz "Nut"
  .asciiz "Observation"
  .asciiz "Of"
  .asciiz "Off"
  .asciiz "Offer"
  .asciiz "Office"
  .asciiz "Oil"
  .asciiz "Old"
  .asciiz "On"
  .asciiz "Only"
  .asciiz "Open"
  .asciiz "Operation"
  .asciiz "Opinion"
  .asciiz "Opposite"
  .asciiz "Or"
  .asciiz "Orange"
  .asciiz "Order"
  .asciiz "Organization"
  .asciiz "Ornament"
  .asciiz "Other"
  .asciiz "Out"
  .asciiz "Oven"
  .asciiz "Over"
  .asciiz "Owner"
  .asciiz "Page"
  .asciiz "Pain"
  .asciiz "Paint"
  .asciiz "Paper"
  .asciiz "Parallel"
  .asciiz "Parcel"
  .asciiz "Part"
  .asciiz "Past"
  .asciiz "Paste"
  .asciiz "Payment"
  .asciiz "Peace"
  .asciiz "Pen"
  .asciiz "Pencil"
  .asciiz "Person"
  .asciiz "Physical"
  .asciiz "Picture"
  .asciiz "Pig"
  .asciiz "Pin"
  .asciiz "Pipe"
  .asciiz "Place"
  .asciiz "Plane"
  .asciiz "Plant"
  .asciiz "Plate"
  .asciiz "Play"
  .asciiz "Please"
  .asciiz "Pleasure"
  .asciiz "Plough"
  .asciiz "Pocket"
  .asciiz "Point"
  .asciiz "Poison"
  .asciiz "Polish"
  .asciiz "Political"
  .asciiz "Poor"
  .asciiz "Porter"
  .asciiz "Position"
  .asciiz "Possible"
  .asciiz "Pot"
  .asciiz "Potato"
  .asciiz "Powder"
  .asciiz "Power"
  .asciiz "Present"
  .asciiz "Price"
  .asciiz "Print"
  .asciiz "Prison"
  .asciiz "Private"
  .asciiz "Probable"
  .asciiz "Process"
  .asciiz "Produce"
  .asciiz "Profit"
  .asciiz "Property"
  .asciiz "Prose"
  .asciiz "Protest"
  .asciiz "Public"
  .asciiz "Pull"
  .asciiz "Pump"
  .asciiz "Punishment"
  .asciiz "Purpose"
  .asciiz "Push"
  .asciiz "Put"
  .asciiz "Quality"
  .asciiz "Question"
  .asciiz "Quick"
  .asciiz "Quiet"
  .asciiz "Quite"
  .asciiz "Rail"
  .asciiz "Rain"
  .asciiz "Range"
  .asciiz "Rat"
  .asciiz "Rate"
  .asciiz "Ray"
  .asciiz "Reaction"
  .asciiz "Reading"
  .asciiz "Ready"
  .asciiz "Reason"
  .asciiz "Receipt"
  .asciiz "Record"
  .asciiz "Red"
  .asciiz "Regret"
  .asciiz "Regular"
  .asciiz "Relation"
  .asciiz "Religion"
  .asciiz "Representative"
  .asciiz "Request"
  .asciiz "Respect"
  .asciiz "Responsible"
  .asciiz "Rest"
  .asciiz "Reward"
  .asciiz "Rhythm"
  .asciiz "Rice"
  .asciiz "Right"
  .asciiz "Ring"
  .asciiz "River"
  .asciiz "Road"
  .asciiz "Rod"
  .asciiz "Roll"
  .asciiz "Roof"
  .asciiz "Room"
  .asciiz "Root"
  .asciiz "Rough"
  .asciiz "Round"
  .asciiz "Rub"
  .asciiz "Rule"
  .asciiz "Run"
  .asciiz "Sad"
  .asciiz "Safe"
  .asciiz "Sail"
  .asciiz "Salt"
  .asciiz "Same"
  .asciiz "Sand"
  .asciiz "Say"
  .asciiz "Scale"
  .asciiz "School"
  .asciiz "Science"
  .asciiz "Scissors"
  .asciiz "Screw"
  .asciiz "Sea"
  .asciiz "Seat"
  .asciiz "Second"
  .asciiz "Secret"
  .asciiz "Secretary"
  .asciiz "See"
  .asciiz "Seed"
  .asciiz "Seem"
  .asciiz "Selection"
  .asciiz "Self"
  .asciiz "Send"
  .asciiz "Sense"
  .asciiz "Separate"
  .asciiz "Serious"
  .asciiz "Servant"
  .asciiz "Sex"
  .asciiz "Shade"
  .asciiz "Shake"
  .asciiz "Shame"
  .asciiz "Sharp"
  .asciiz "Sheep"
  .asciiz "Shelf"
  .asciiz "Ship"
  .asciiz "Shirt"
  .asciiz "Shock"
  .asciiz "Shoe"
  .asciiz "Short"
  .asciiz "Shut"
  .asciiz "Side"
  .asciiz "Sign"
  .asciiz "Silk"
  .asciiz "Silver"
  .asciiz "Simple"
  .asciiz "Sister"
  .asciiz "Size"
  .asciiz "Skin"
  .asciiz "Skirt"
  .asciiz "Sky"
  .asciiz "Sleep"
  .asciiz "Slip"
  .asciiz "Slope"
  .asciiz "Slow"
  .asciiz "Small"
  .asciiz "Smash"
  .asciiz "Smell"
  .asciiz "Smile"
  .asciiz "Smoke"
  .asciiz "Smooth"
  .asciiz "Snake"
  .asciiz "Sneeze"
  .asciiz "Snow"
  .asciiz "So"
  .asciiz "Soap"
  .asciiz "Society"
  .asciiz "Sock"
  .asciiz "Soft"
  .asciiz "Solid"
  .asciiz "Some"
  .asciiz "Son"
  .asciiz "Song"
  .asciiz "Sort"
  .asciiz "Sound"
  .asciiz "Soup"
  .asciiz "South"
  .asciiz "Space"
  .asciiz "Spade"
  .asciiz "Special"
  .asciiz "Sponge"
  .asciiz "Spoon"
  .asciiz "Spring"
  .asciiz "Square"
  .asciiz "Stage"
  .asciiz "Stamp"
  .asciiz "Star"
  .asciiz "Start"
  .asciiz "Statement"
  .asciiz "Station"
  .asciiz "Steam"
  .asciiz "Steel"
  .asciiz "Stem"
  .asciiz "Step"
  .asciiz "Stick"
  .asciiz "Sticky"
  .asciiz "Stiff"
  .asciiz "Still"
  .asciiz "Stitch"
  .asciiz "Stocking"
  .asciiz "Stomach"
  .asciiz "Stone"
  .asciiz "Stop"
  .asciiz "Store"
  .asciiz "Story"
  .asciiz "Straight"
  .asciiz "Strange"
  .asciiz "Street"
  .asciiz "Stretch"
  .asciiz "Strong"
  .asciiz "Structure"
  .asciiz "Substance"
  .asciiz "Such"
  .asciiz "Sudden"
  .asciiz "Sugar"
  .asciiz "Suggestion"
  .asciiz "Summer"
  .asciiz "Sun"
  .asciiz "Support"
  .asciiz "Surprise"
  .asciiz "Sweet"
  .asciiz "Swim"
  .asciiz "System"
  .asciiz "Table"
  .asciiz "Tail"
  .asciiz "Take"
  .asciiz "Talk"
  .asciiz "Tall"
  .asciiz "Taste"
  .asciiz "Tax"
  .asciiz "Teaching"
  .asciiz "Tendency"
  .asciiz "Test"
  .asciiz "Than"
  .asciiz "That"
  .asciiz "The"
  .asciiz "Then"
  .asciiz "Theory"
  .asciiz "There"
  .asciiz "Thick"
  .asciiz "Thin"
  .asciiz "Thing"
  .asciiz "This"
  .asciiz "Thought"
  .asciiz "Thread"
  .asciiz "Throat"
  .asciiz "Through"
  .asciiz "Through"
  .asciiz "Thumb"
  .asciiz "Thunder"
  .asciiz "Ticket"
  .asciiz "Tight"
  .asciiz "Till"
  .asciiz "Time"
  .asciiz "Tin"
  .asciiz "Tired"
  .asciiz "To"
  .asciiz "Toe"
  .asciiz "Together"
  .asciiz "Tomorrow"
  .asciiz "Tongue"
  .asciiz "Tooth"
  .asciiz "Top"
  .asciiz "Touch"
  .asciiz "Town"
  .asciiz "Trade"
  .asciiz "Train"
  .asciiz "Transport"
  .asciiz "Tray"
  .asciiz "Tree"
  .asciiz "Trick"
  .asciiz "Trouble"
  .asciiz "Trousers"
  .asciiz "True"
  .asciiz "Turn"
  .asciiz "Twist"
  .asciiz "Umbrella"
  .asciiz "Under"
  .asciiz "Unit"
  .asciiz "Up"
  .asciiz "Use"
  .asciiz "Value"
  .asciiz "Verse"
  .asciiz "Very"
  .asciiz "Vessel"
  .asciiz "View"
  .asciiz "Violent"
  .asciiz "Voice"
  .asciiz "Waiting"
  .asciiz "Walk"
  .asciiz "Wall"
  .asciiz "War"
  .asciiz "Warm"
  .asciiz "Wash"
  .asciiz "Waste"
  .asciiz "Watch"
  .asciiz "Water"
  .asciiz "Wave"
  .asciiz "Wax"
  .asciiz "Way"
  .asciiz "Weather"
  .asciiz "Week"
  .asciiz "Weight"
  .asciiz "Well"
  .asciiz "West"
  .asciiz "Wet"
  .asciiz "Wheel"
  .asciiz "When"
  .asciiz "Where"
  .asciiz "While"
  .asciiz "Whip"
  .asciiz "Whistle"
  .asciiz "White"
  .asciiz "Who"
  .asciiz "Why"
  .asciiz "Wide"
  .asciiz "Will"
  .asciiz "Wind"
  .asciiz "Window"
  .asciiz "Wine"
  .asciiz "Wing"
  .asciiz "Winter"
  .asciiz "Wire"
  .asciiz "Wise"
  .asciiz "With"
  .asciiz "Woman"
  .asciiz "Wood"
  .asciiz "Wool"
  .asciiz "Word"
  .asciiz "Work"
  .asciiz "Worm"
  .asciiz "Wound"
  .asciiz "Writing"
  .asciiz "Wrong"
  .asciiz "Year"
  .asciiz "Yellow"
  .asciiz "Yes"
  .asciiz "Yesterday"
  .asciiz "You"
  .asciiz "Young"
  .asciiz "Android"
  .word EOL
 
;------------------------------------------
; Reset address (boot)
;------------------------------------------
  .org $fffc
  .word reset
  .word $0000





