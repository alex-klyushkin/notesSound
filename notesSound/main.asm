;
; notesSound.asm
;
; Created: 27.02.2020 22:37:21
; Author : Алексей
;



.include "tn2313adef.inc"



.def temp1 = r16
.def temp2 = r17
.def temp3 = r18
.def octavaNo = r19
.def notaFreq = r20



.MACRO SETUP_OCR1B
	mov temp1, @0
	mov temp2, @1
	out OCR1BH, temp2
	out OCR1BL, temp1
.ENDMACRO



.MACRO SETUP_OCR1A
	mov temp1, @0
	mov temp2, @1
	out OCR1AH, temp2
	out OCR1AL, temp1
.ENDMACRO



.MACRO LOAD_WORD_TO_Y
	mov ZL, @0
	mov ZH, @1
	mov temp1, @2
	clc
	rol temp1
	clr temp2
	add ZL, temp1
	adc ZH, temp2
	lpm YL, Z+
	lpm YH, Z
.ENDMACRO



; interrupts vector
rjmp START
.org 11
rjmp PORTB_PIN_CHANGE_INTERRUPT
.org 21
rjmp PORTD_PIN_CHANGE_INTERRUPT



PORTB_PIN_CHANGE_INTERRUPT:
	clr temp2
	in temp1, PINB
counting_cycle_portb:
	ror temp1
	inc temp2
	brcs counting_cycle_portb
	
	dec temp2
	cpi temp2, 4
	brsh exit_portb_pin_change
	mov octavaNo, temp2

exit_portb_pin_change:
	reti



PORTD_PIN_CHANGE_INTERRUPT:
	clr temp2
	in temp1, PIND
counting_cycle_portd:
	ror temp1
	inc temp2
	brcs counting_cycle_portd
	dec temp2

	cpi temp2, 7
	brlo load_new_freq
	rcall STOP_16BIT_TIMER
	rcall CLEANUP_16BIN_TIMER_MODE
	reti

load_new_freq:
	mov notaFreq, temp2
	; load freq to Y
	ldi temp1, LOW(octavaAddrs * 2)
	ldi temp2, HIGH(octavaAddrs * 2)
	LOAD_WORD_TO_Y temp1, temp2, octavaNo
	LOAD_WORD_TO_Y YL, YH, notaFreq

	; compare Y and OCR1B
	in temp1, OCR1BL
	in temp2, OCR1BH
	cp temp2, YH
	brne set_new_freq_to_timer
	cp temp1, YL
	brne set_new_freq_to_timer
	rjmp enable_16bit_timer

set_new_freq_to_timer:
	SETUP_OCR1A YL, YH
	clc
	ror YH
	ror YL
	SETUP_OCR1B YL, YH
enable_16bit_timer:
	rcall SETUP_TIMER1_FAST_PWM_OUTPUTB
	rcall START_16BIT_TIMER_NO_PRESCALING
	reti



; Replace with your application code
START:
	; set up stack
	ldi temp1, LOW(RAMEND)
	out SPL, temp1

	rcall SETUP_TIMER1_FAST_PWM_OUTPUTB

	; PORTD 0-6 bit - input, pull-up resistor on
	; Enable pin change interrupts on all portd
	ldi temp1, 0x7F
	out PORTD, temp1
	out PCMSK2, temp1
	; PORTB4 - output OC1B
	ldi temp1, (1 << PORTB4)
	out DDRB, temp1
	; PORTB 0 - 3 - input, pull-up resistor on
	; Enable pin change interrupts on portb 0-3
	ldi temp1, 0x0F
	out PORTB, temp1
	out PCMSK0, temp1

	; pin change interrupt on portd and protb enable
	ldi temp1, (1 << PCIE2 | 1 << PCIE0)
	out GIMSK, temp1

	; sleep enable
	in temp1, MCUCR
	sbr temp1, (1 << SE)
	out MCUCR, temp1

	; enable global interrupt
	sei

inf_loop:
	sleep
	rjmp inf_loop



SETUP_TIMER1_FAST_PWM_OUTPUTB:
	; Clear OC1B on Compare Match, set OC1B at TOP
	; Fast PWM, OCR1A TOP
	ldi temp1, (1 << COM1B1 | 1 << WGM11 | 1 << WGM10)
	out TCCR1A, temp1
	ldi temp1, (1 << WGM13 | 1 << WGM12)
	out TCCR1B, temp1
	ret



START_16BIT_TIMER_NO_PRESCALING:
	in temp1, TCCR1B
	sbr temp1, (1 << CS10)
	out TCCR1B, temp1
	ret



STOP_16BIT_TIMER:
	in temp1, TCCR1B
	cbr temp1, (1 << CS12 | 1 << CS11 | 1 << CS10)
	out TCCR1B, temp1
	clr temp1
	out TCNT1H, temp1
	out TCNT1L, temp2
	ret



CLEANUP_16BIN_TIMER_MODE:
	clr temp1
	out TCCR1A, temp1
	out TCCR1B, temp1
	ret



octavaOne:   .dw 32063, 28566, 25449, 24020, 21400, 19065, 16985
octavaTwo:   .dw 16032, 14283, 12724, 12010, 10700,  9533,  8492
octavaThree: .dw  8016,  7141,  6362,  6005,  5350,  4766,  4246
octavaFour:  .dw  4008,  3571,  3181,  3003,  2675,  2383,  2123
octavaAddrs: .dw octavaOne * 2, octavaTwo * 2, octavaThree * 2, octavaFour * 2