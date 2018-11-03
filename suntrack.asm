;	Copyright (C) 2018 Dale Giancono (d.giancono@gmail.com)
;	This program is free software; you can redistribute it and/or modify
;	it under the terms of the GNU General Public License as published by
;	the Free Software Foundation; either version 2 of the License, or
;	(at your option) any later version.
;	This program is distributed in the hope that it will be useful,
;	but WITHOUT ANY WARRANTY; without even the implied warranty of
;	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;	GNU General Public License for more details.


.include "C:\VMLAB\include\M32DEF.inc"

.def temp = r16         	; General purpose register.
.def adc0 = r17 		; Left position LDR.
.def adc1 = r18			; Right position LDR.
.def adc2 = r19			; Top postion LDR.
.def adc3 = r20			; Bottom position LDR.
.def adc4 = r21			; Solar panel output.
.def x_count = r22		; Stores x axis motor movement direction.
.def y_count = r23		; Stores y axis motor movement direction.
.def delay_count = r24		; delay loop counter.

.equ motor_speed = $7F		; higher numbers mean faster movement.
.equ threshold = $2		; Stores sensitivity to LDR value differences.


;**************ATMEGA 32 PORT INFORMATION***************************************
; PORTA is used for analogue to digital conversion. ADC0-ADC3 are used for the LDRs.
; ADC4 is used to measure the output of the solar panel.
; PORTB is used to display the output of the solar panel using the OUSB LED bar.
; PORTC is used to drive to motor driver chip. PORTB0-1 controls x axis. PORTB2-3 control y axis.

Initialise:
	LDI temp, $FF 		
	OUT DDRB, temp		; Sets all PORTB pins as outputs.		
	OUT DDRC, temp  	; Sets all PORTC pins as outputs.
	LDI temp, $00
	OUT DDRA, temp  	; Sets all PORTA pins as inputs.
	OUT PORTB, temp		; Clears all PORTB pins, turning them low.
   OUT PORTC, temp    		; Clears all PORTC pins, turning them low.

main:
	CALL data_acquire 	; The data acquisition phase of the program cycle.
	CALL data_algorithm  	; The data algorithm phase of the program cycle.
	CALL motor_movement  	; The motor movement phase of the program cycle.
	CALL delay
	RJMP main            	; Infinitely repeat the main label.

;**********************************************************************************
;***************** Data Acquisition ******************************************************
; For the data acquisition phase, we convert the 4 LDR and solar cell output signals in to
; an 8 bit digital value. We do this do utilising the ATMEGA32s ADC0-4 found on PORTA0-4 pins.
;
; ADC0 = Left LDR sensor.
; ADC1 = right LDR sensor.
; ADC2 = up LDR sensor.
; ADC3 = down LDR sensor.

data_acquire:
	LDI temp, $60		; Move ADMUX adc0 value to temp register.
	CALL adc_start		; Starts the ADC conversion proccess.
	CALL convert_check	; Checks if conversion is complete.
	CALL adc0_store		; Stores conversion result in adc0 register.
	
	LDI temp, $61		; Move ADMUX adc1 value to temp register.
	CALL adc_start		; Starts the ADC conversion proccess.
	CALL convert_check	; Checks if conversion is complete.
	CALL adc1_store		; Stores conversion result in adc1 register.
	
	LDI temp, $62		; Move ADMUX adc2 value to temp register.
	CALL adc_start		; Starts the ADC conversion proccess.
	CALL convert_check	; Checks if conversion is complete.
	CALL adc2_store		; Stores conversion result in adc2 register.
	
	LDI temp, $63		; Move ADMUX adc3 value to temp register.
	CALL adc_start		; Starts the ADC conversion proccess.
	CALL convert_check	; Checks if conversion is complete.
	CALL adc3_store		; Stores conversion result in adc3 register.
	
	LDI temp, $64		; Move ADMUX adc4 value to temp register.
	CALL adc_start		; Starts the ADC conversion proccess.
	CALL convert_check	; Checks if conversion is complete.
	CALL adc4_store		; Stores conversion result in adc4 register.
	RJMP exit		; Returns to main label.

adc_start:
   	OUT ADMUX, temp 	; Selects top reference voltage as AVCC, left adjusted result, and ADC channel.
	LDI temp, $90
	OUT ADCSR, temp		; Enables ADC, disables auto trigger, disables interupt enable, division factor 2 prescaler.
	SBI ADCSR, ADSC		; Sets start conversion bit. Starts the ADC conversion.
	RJMP exit		; Returns to data_ acquire label.

convert_check:
	SBIC ADCSR, ADSC	; Skips the next instruction with the ADSC bit in ADCSR is still set.
				; This bit clears once conversion is complete.
	RJMP convert_check	; If conversion is still going, repeat convert_check.
	RJMP exit		; If conversion is over, exit to data_acquire label.

adc0_store:
	IN adc0, ADCH		; Moves ADC0 data to adc0 register.
	RJMP exit            	; Returns to data_acquire label.
adc1_store:
	IN adc1, ADCH		; Moves ADC1 data to adc1 register.
	RJMP exit            	; Returns to data_acquire label.
adc2_store:
	IN adc2, ADCH		; Moves ADC2 data to adc2 register.
	RJMP exit            	; Returns to data_acquire label.
adc3_store:
	IN adc3, ADCH		; Moves ADC3 data to adc3 register.
	RJMP exit            	; Returns to data_acquire label.
adc4_store:
	IN adc4, ADCH     	; Moves ADC4 data to adc4 register.
	RJMP exit            	; Returns to data_acquire label.

;*****************************************************************************************
;***************** Data Algorithm******************************************************
; For the data algorithm phase, we compare left/right and top/bottom LDR values and attain differneces to determine
; which direction the motor needs to move in order for the solar cell to have the maximum output voltage.
; There is also a sensitivity threshold for the LDR values. Small differences are acceptable and will
; prevent the solar panel for constantly moving.

data_algorithm:
	CLR x_count
	CLR y_count
	CALL x_axis	 	; Calls x_axis data algorithm label.
	CALL y_axis         	; Calls y_axis data algorithm label.
	RJMP exit            	; Returns to main label.

x_axis:
	CP adc0, adc1		; Compares left and right LDR values.
	BRSH left_threshold 	; If left value is greater than right value, the x axis must move in the left direction.
				; Branch to left_threshold label.

	CALL right_threshold	; Else if rigt value is greater than left value, the x axis must move in the right direction.
				; Branch to right_threshold label.						
	RJMP exit            	; Returns to data_algorithm labl.
	
y_axis:
	CP adc2, adc3		; Compares top and bottom LDR values.
	BRSH up_threshold	; If top value is greater than bottom value, the y axis must move in the up direction.
				; Branch to up_threshold label.
	CALL down_threshold  	; If bottom value is greater than top value, the y axis must move in the down direction.
				; Branch to down_threshold label.
	RJMP exit            	; Returns to data_algorithm labl.

left_threshold:
	SUB adc0, adc1		; If left value was greater than right value, the x axis must move in the left direction.
				; But first we must make sure that the difference between the two LDRs is greater than our threshold.
				; To do this we first subtract the adc0 value from adc1.
	CPI adc0, threshold  	; We then compare the result with the defined threshold number as specified at the top of the program.
	BRLO exit            	; If the result was less than the threshold number, the x axis is not required to move.
				; So we branch to the exit label, and in return, return to the data_algorithm label.
	LDI x_count, $1      	; If the result was higher than the threshold number, the x axis is required to move left.
				; To tell the motor this is the case, we make the x_count register equal $1. We will decode this value later.
	RJMP exit  		; Returns to x_axis label.

right_threshold:
	SUB adc1, adc0		; If right value was greater than left value, the x axis must move in the right direction.
				; But first we must make sure that the difference between the two LDRs is greater than our threshold.
				; To do this we first subtract the adc1 value from adc0.
	CPI adc1, threshold  	; We then compare the result with the defined threshold number as specified at the top of the program.
	BRLO exit            	; If the result was less than the threshold number, the x axis is not required to move.
				; So we branch to the exit label, and in return, return to the data_algorithm label.
	LDI x_count, $2      	; If the result was higher than the threshold number, the x axis is required to move right.
				; To tell the motor this is the case, we make the x_count register equal $2. We will decode this value later.						
	RJMP exit            	; Returns to x_axis label.

up_threshold:
	SUB adc2, adc3       	; If top value was greater than right value, the x axis must move in the left direction.
				; But first we must make sure that the difference between the two LDRs is greater than our threshold.
				; To do this we first subtract the adc2 value from adc3.
	CPI adc2, threshold 	; We then compare the result with the defined threshold number as specified at the top of the program.
	BRLO exit            	; If the result was less than the threshold number, the y axis is not required to move.
				; So we branch to the exit label, and in return, return to the data_algorithm label.
	LDI y_count, $10     	; To tell the motor this is the case, we make the y_count register equal $1. We will decode this value later.
	RJMP exit		; Exits to y_axis label.  	

down_threshold:	
	SUB adc3, adc2       	; If bottom value was greater than the top value, the x axis must move in the bottom direction.
				; But first we must make sure that the difference between the two LDRs is greater than our threshold.
				; To do this we first subtract the adc3 value from adc2.
	CPI adc3, threshold  	; We then compare the result with the defined threshold number as specified at the top of the program.
	BRLO exit            	; If the result was less than the threshold number, the y axis is not required to move.
				; So we branch to the exit label, and in return, return to the data_algorithm label.
	LDI y_count, $20     	; If the result was higher than the threshold number, the y axis is required to move down.
				; To tell the motor this is the case, we make the y_count register equal $20. We will decode this value later.							
	RJMP exit            	; Exits to y_axis label.

exit:                   	; Returns to main label.
	ret

;******************************************************************************************
;***************** Motor Movement******************************************************

motor_movement:
	CALL decode            	; Calls decode label.
	CALL output		; Calls output label.
   RJMP exit			; Returns to main label.

decode:  	
   LDI ZH, high(motor<<1)	; Set the base pointer to the table.
   LDI ZL, low(motor<<1)
	OR x_count, y_count     ; ORs x_count and y_count. y_count will be stored in the 4 MSBs, x_count in the 4 LSBs.
	ADD ZL, x_count         ; Offsets address with temp value
	LPM temp, Z		; Moves the decoded data value to the temp register. This value will be outputed to the motors.
	RJMP exit               ; Return to motor_movement label.

output:
	OUT PORTC, temp     	; Output temp value retrieved from decode label to PORTB
	CALL delay_on		; Call the delay_on label. This delay will specify how long the on
				; cycle of the PWM motor signal will be.
	LDI temp, $C0										
	OUT PORTC, temp 	; Output temp value $0. This will turn all motors off
	CALL delay_off		; Call the delay_off label. This delay will specify how long the off
				; cycle of the PWM motor signal will be.
	RJMP exit               ; Returns to motor_movement label.
	
;**********************************************************************************************
;********************** Universal Labels ********************************************************
; To create a delay for our PWM on and off times, we use a two tiered delay with an inner and outer loop.
; For the delay_on lebel, the first inner loop counts down from 255 to 0. Once 0 has been reached, the outer loop decrements.
; The outer loops starting number is specified by the user, by inputing a value in to the motor_speed register.
; The larger number that the motor_speed register holds, the faster the motor will appear to move.
; delay_off works in the exact same manner, except the outer loop value remains at $F and should not be changed.

delay_on:
		LDI temp, 0xFF              	; Sets couter inner loop value at 255.
		LDI delay_count, motor_speed
		RJMP delay_loop            	; Jumps to loop count down.

delay_off:
		LDI temp, 0xFF              	; Sets couter loop value at 255.
		LDI delay_count, $8
		RJMP delay_loop            	; Jumps to loop count down.

delay:
		LDI temp, 0xFF              	; Sets couter loop value at 255.
		LDI delay_count, $FF
		RJMP delay_loop            	; Jumps to loop count down.

delay_loop:
		DEC temp        	; Decrements couter value by one.
		CPI temp, $00           ; Checks if counter value is 0.
		BREQ delay_count        ; If it is we exit the delay loop.
		RJMP delay_loop         ; If it isn't we repeat the process.	

delay_count:
		DEC delay_count         ; Decrements couter value by one.
		CPI delay_count, $00    ; Checks if counter value is 0.
		BREQ exit               ; If it is we exit the delay loop.
		RJMP delay_loop         ; If it isn't we repeat the process.	





;****************************************************************************

;PORTB CONNECTIONS!!!!
;PORTB0 = x axis orange
;PORTB1 = x axis brown
;PORTB2 = y axis orange
;PORTB3 = y axis brown
;VCC+   = x axis red
;VCC+   = y axis red


;PORTB OUTPUT FOR MOTOR DRIVER
; 0b11000000 ($0) = no movement
; 0b11000100 ($1)($C4)= move left
; 0b11001000 ($2)($C8)= move right
; 0b11010000 ($4)($D0)= move up
; 0b11100000 ($8)($E0)= move down
; 0b11010100 ($5)($D4)= move up and left
; 0b11011000 ($6)($D8)= move up and right
; 0b11100100 ($9)($E4)= move down and left
; 0b11101000 ($A)($E8)= move down and right

motor:	
	;************** x_count *************************************************
	;x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xA  xB  xC  xD  xE  xF			*
.db $C0, $C4, $C8, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0 ;0x 	y_count
.db $D0, $D4, $D8, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0 ;1x 		*
.db $E0, $E4, $E8, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0 ;2x		*	
                                                                         	
                                                                         	










