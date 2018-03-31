; Programa para el control de un motor DC mediante tres botones, de modo que
; uno de ellos lo arranca, el otro lo detiene y el tercero cambia el sentido de
; giro, usando el microcontrolador PIC16F84A.
;
; Pablo Salgado
; 
;
; Microcontroladores y Microprocesadores
; Escuela de Ciencias Básicas, Tecnología e Ingeniería
; UNAD

; Se incluye el archivo de definición de registros y otras configuraciones 
; de Microchip Technology
#include "p16f84a.inc"

__CONFIG _FOSC_XT & _WDTE_ON & _PWRTE_ON & _CP_OFF
    
; Configuración de registros de uso general 
LASTPB	    EQU	0xC		    ; Va a guardar el estado anterior del puerto
TMP1	    EQU 0xD		    ; Registro temporal para guardar puerto B
TMP2	    EQU	0xF		    ; Registro auxiliar para la rutina de invesión	    

    
RES_VECT    CODE 0x0000		    ; Vector de reinicio del procesador
    GOTO    START                   ; Iniciar el programa

RSI_VECT    CODE 0x0004		    ; Vector de rutina de servicio de interrupciones
    GOTO    RSI                     ; Ir a la rutina de servicio de interrupciones
	  
MAIN_PROG   CODE		    ; let linker place main program

START
    ; ==========================================================================
    ; Configuración del puerto B
    ;
    ; Los dos bits de menor peso se usan como salida y van a controlar las
    ; entradas del puente H L298
    ;
    ; Se van a utilizar las interrupciones del puerto B en los bits 4, 5, y 6 de
    ; la siguiente forma:
    ; PORTB.4 => START
    ; PORTB.5 => STOP
    ; PORTB.6 => INVERT
    ;
    ; Se requiere entonces configurar el puerto con 0xFC, que configura los bits
    ; 0,1 de salida y el resto de entrada.
    ; ==========================================================================
   
    ; Configurar el puerto B.
    BSF	    STATUS, RP0		    ; Se selecciona el banco 1 para configurar    
    MOVLW   0xFC		    ; el registro TRISB con 0xFC indicando así
    MOVWF   TRISB		    ; que los dos bits de menor peso son OUT

    ; Se habilitan las interrupciones en el puerto B utilizando al flanco de
    ; bajada puesto que los pines van a estar en 1 y el botón los conecta a 0
    BSF	    INTCON, GIE		    ; Habilita las interrupciones
    BSF	    INTCON, RBIE	    ; Habilita las interrupciones en puerto B
    BCF	    OPTION_REG, INTEDG	    ; Define el flanco de bajada
    
    ; El estado inicial del puerto B es Fx, donde x indica que no interesa el 
    ; estado de los bits que no generan interrupción, de modo que no se tendrán
    ; en cuenta en las operaciones para determinar que pin ha generado la
    ; interrupción.
    ; Así, inicialmente todos los pines de interrupción están en 1, de modo que
    ; el estado inicial se puede considerar 0xFF
    MOVLW   0xFF
    MOVWF   LASTPB 

    ; El motor comienza apagado. Esto se logra colocando 00 o 11 en los pines de
    ; entrada del motor 1 del puente H L298. En otras palabras, es necesario
    ; colocar 00 en los dos bits de menor peso del puerto B:
    ; PORTB.0 = 0
    ; PORTB.1 = 0
    BCF	    STATUS, RP0		    ; Se selecciona el banco 0 para acceder al
    BCF	    PORTB, RB0		    ; puerto B y colocar los dos bits en 0
    BCF	    PORTB, RB1
        
    ; ==========================================================================
    ; Rutina para controlar el motor. Simplemente se pone a dormir el micro en
    ; espera que ocurra una interrupción.
    ; ==========================================================================
MOTOR    
    SLEEP
    GOTO    MOTOR

    ; ==========================================================================
    ; Rutina de servicio de interrupciones.
    ; ==========================================================================    
RSI
    ; Se determina que la interrupción se haya generado en el puerto B, de lo 
    ; contrario se retorna de la interrupción
    BTFSS   INTCON, RBIF
    RETFIE
    
    ; Se ha determinado que se ha generado una interrupción en el puerto B. Se
    ; hace necesario determinar cual pin ha causado la interrupción.
    MOVF    PORTB, 0		    ; Se guarda el estado actual del puerto B
    MOVWF   TMP1		    ; Este valor se dejará en LASTPB al terminar
    
    ; Esta operación XOR determina si ha cambiado algún bit desde la última vez
    ; que se generó una interrupción. Es decir, si la ultima vez se generó una 
    ; interrupción en RB4 (START) y se vuelve a generar esta misma, el resultado
    ; es 0x0 y no es necesario volver a iniciar el motor. Si en cambio se genera
    ; una interrupción en RB5 (STOP), el resultado es 0x2 y se debe atender la
    ; interrupción para detener el motor.
    XORWF   LASTPB, 1		    
    
    BTFSC   LASTPB, RB4		    ; ¿El bit 4 ha cambiado?
    CALL    START_ENG		    ; El bit 4 cambió. Se debe arrancar el motor.
    
    BTFSC   LASTPB, RB5		    ; ¿El bit 5 ha cambiado?
    CALL    STOP_ENG		    ; El bit 5 cambió. Se debe detener el motor.

    BTFSC   LASTPB, RB6		    ; ¿El bit 6 ha cambiado?
    CALL    INV_ENG		    ; El bit 6 cambió. Se debe invertir la marcha.
				    ; del motor.
    
    ; Se recupera el estado del puerto B al iniciar la rutina de servicio de
    ; interrupción.
    MOVF    TMP1, 0
    MOVWF   LASTPB
    
    ; Se borran las banderas de interrupción y termina la rutina de servicio
    BCF	    INTCON, RBIF
    
    RETFIE

    ; ==========================================================================
    ; Rutina para arrancar el motor.
    ; ==========================================================================        
START_ENG
    BTFSS   PORTB, RB4		    ; Se retorna si este pin no ha generado la
    RETURN			    ; interrupción
    
    ; Para arrancar el motor se debe colocar 01 o 10 en los pines de entrada del
    ; motor 1 del puente H L298.
    ; De modo que simplemente se coloca 1 en RB0 para que el motor arranque
    BSF PORTB, RB0
    RETURN
    
    ; ==========================================================================
    ; Rutina para detener el motor.
    ; ==========================================================================        
STOP_ENG
    BTFSS   PORTB, RB5		    ; Se retorna si este pin no ha generado la
    RETURN			    ; interrupción

    ; Para detener el motor se debe colocar 00 o 11 en los pines de entrada del
    ; motor 1 del puente H L298.
    ; De modo que simplemente se coloca 0 en RB0 y RB1 para deterner el motor.
    BCF	PORTB, RB0
    BCF	PORTB, RB1
    RETURN

    ; ==========================================================================
    ; Rutina para invertir la marcha del motor.
    ; ==========================================================================        
INV_ENG
    BTFSS   PORTB, RB6		    ; Se retorna si este pin no ha generado la
    RETURN			    ; interrupción

    ; Solo se puede invertir si el motor está en marcha, es decir los dos bits
    ; de menor peso del puerto B están en 01 o 10.
    
    ; Si se tiene 00, no se puede invertir la marcha
    MOVF    PORTB, 0		    ; Se lee el estado del puerto B al registro W
    ANDLW   0x3			    ; Y se aislan los dos bits de menor peso
    BTFSC   STATUS, Z		    ; ¿Es diferente de cero el resultado?
    RETURN			    ; Retorna porque se tiene 00
    
    ; Si se tiene 11, no se puede invertir la marcha
;    MOVF    PORTB, 0		    ; Se lee el estado del puerto B al registro W
;    ANDLW   0x3			    ; Y se aislan los dos bits de menor peso
;    SUBLW   0x3
;    BTFSC   STATUS, Z		    ; ¿Es diferente de cero el resultado?
;    RETURN			    ; Retorna porque se tiene 11

    ; Si se tiene 01, entonces se coloca 10
    MOVF    PORTB, 0		    ; Se lee el estado del puerto B al registro W
    ANDLW   0x3			    ; Y se aislan los dos bits de menor peso
    SUBLW   0x1			    
    BTFSS   STATUS, Z		    ; ¿Es diferente de cero el resultado?    
    GOTO    T10			    ; Entonces se intenta con 10
    
    ; Invertir la marcha del motor, se coloca RB0=0 y RB1=1
    BCF	    PORTB, RB0
    BSF	    PORTB, RB1
    RETURN
    
    ; Se tiene 10, entonces se coloca 01
T10 BSF	    PORTB, RB0
    BCF	    PORTB, RB1
    
    RETURN
    
    END
