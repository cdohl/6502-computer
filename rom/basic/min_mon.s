; minimal monitor for EhBASIC and 6502 simulator V1.05
; tabs converted to space, tabwidth=6

; To run EhBASIC on the simulator load and assemble [F7] this file, STArt the simulator
; running [F6] then STArt the code with the RESET [CTRL][SHIFT]R. Just selecting RUN
; will do nothing, you'll still have to do a reset to run the code.

      .include "basic.s"

; put the IRQ and MNI code in RAM so that it can be changed

IRQ_vec     = VEC_SV+2        ; IRQ code vector
NMI_vec     = IRQ_vec+$0A     ; NMI code vector


PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

E      = %10000000    ; LCD enable
E_C    = %01111111    ; enable complement
RW     = %00100000    ; LCD RW 
RS     = %00010000    ; LCD set char
RSWE_C = %01001111    ; RSWE complement
TX     = %00001000    ; TX pin *output"
TX_C   = %11110111    ; TX pin complement


; now the code. all this does is set up the vectors and interrupt code
; and wait for the user to select [C]old or [W]arm STArt. nothing else
; fits in less than 128 bytes

      .segment "CODE"         ; pretend this is in a 1/8K ROM

; reset vector points here

RES_vec
      CLD                     ; clear decimal mode
      LDX   #$FF              ; empty STAck
      TXS                     ; set the STAck
      JSR ACIAsetup
      JSR lcd_init

; set up vectors and interrupt code, copy them to page 2

      LDY   #END_CODE-LAB_vec ; set index/count
LAB_stlp
      LDA   LAB_vec-1,Y       ; get byte from interrupt code
      STA   VEC_IN-1,Y        ; save to RAM
      DEY                     ; decrement index/count
      BNE   LAB_stlp          ; loop if more to do

; now do the signon message, Y = $00 here

LAB_signon
      LDA   LAB_mess,Y        ; get byte from sign on message
      BEQ   LAB_nokey         ; exit loop if done

      JSR   V_OUTP            ; output character
      INY                     ; increment index
      BNE   LAB_signon        ; loop, branch always

LAB_nokey
      JSR   V_INPT            ; call scan input device
      BCC   LAB_nokey         ; loop if no key
      JSR   V_OUTP
      AND   #$DF              ; mask xx0x xxxx, ensure upper case
      CMP   #'W'              ; compare with [W]arm STArt
      BEQ   LAB_dowarm        ; branch if [W]arm STArt

      CMP   #'C'              ; compare with [C]old STArt
      BNE   RES_vec           ; loop if not [C]old STArt

      JMP   LAB_COLD          ; do EhBASIC cold STArt

LAB_dowarm
      JMP   LAB_WARM          ; dTX _Co EhBASIC warm STArt

ACIAsetup
      LDA #TX ; set TX pins as PORTA output
      STA DDRA
      JSR tx_clear_bit
 
ACIAout
      PHA
      PHY
      PHX
      LDX #8
      JSR tx_set_bit    ; send a STArt bit
      JSR bit_delay_tx
      ;now we write the bits (5V TTL inverse logic)
write_bits  
      ROR
      BCS tx_bit_on    ; test if MSB is set
      JSR tx_set_bit ; clear TX line
      JMP tx_cont
tx_bit_on
      JSR tx_clear_bit

tx_cont
      JSR bit_delay_tx
      DEX
      BNE write_bits
      JSR tx_clear_bit ; clear for stop bit
      JSR bit_delay_rx
      PLX
      PLY
      PLA
      RTS

tx_set_bit
      PHA
      LDA PORTA
      ORA #TX
      STA PORTA 
      PLA
      RTS

tx_clear_bit
      PHA
      LDA PORTA
      AND #TX_C
      STA PORTA
      PLA
      RTS

bit_delay_tx
      PHX
      LDX #9 ; @1MHz 
bit_delay_tx_1
      DEX
      BNE bit_delay_tx_1
      PLX
      RTS

bit_delay_rx
      PHX
      LDX #13
bit_delay_rx_1
      DEX
      BNE bit_delay_rx_1
      PLX
      RTS

half_bit_delay_rx
      PHX
      LDX #6
half_bit_delay_rx_1
      DEX
      BNE half_bit_delay_rx_1
      PLX
      RTS      

ACIAin
      PHX
      BIT PORTA         ; Put PORTA.6 into V flag
      BVS LAB_nobyw     ; Loop if no STArt bit yet (inverted logic)
      JSR half_bit_delay_rx
      LDX #8

read_bit
      JSR bit_delay_rx
      BIT PORTA         ; Put PORTA.6 into V flag
      BVS recv_1
      CLC               ; we read a 0, put a 0 into the C flag
      JMP rx_done
recv_1
      SEC               ; we read a 1, put a 1 into the C flag
rx_done  
      ROR               ; Rotate A register right, putting C flag as new MSB
      DEX 
      BNE read_bit
      ;otherwise byte is in A
      PLX
      ORA #0
      SEC                     ; flag byte received 
      RTS
LAB_nobyw
      PLX
      CLC                     ; flag no byte received
no_load                       ; empty load vector for EhBASIC
no_save                       ; empty save vector for EhBASIC
      RTS

; vector tables

lcd_init
      LDA #%11111111    ; set all PORTB pins to output
      STA DDRB
      
      LDA #(E|RW|RS|TX) ; set LCD and TX pins as PORTA output
      STA DDRA
      
      LDA #%00111000 ; set 8-bit mode 2 lines display
      JSR lcd__instruction

      LDA #%00001110 ; display on; cursor on; no blink
      JSR lcd__instruction

      LDA #%00000110 ; increment and shift cursor; don't shift display
      JSR lcd__instruction

      LDA #%00000001 ; Clear Display
      JSR lcd__instruction

lcd_wait
      PHA
      LDA #%00000000 ; Port B is input
      STA DDRB
lcdbusy
      LDA PORTA
      AND RSWE_C     ; clear all LCD pins
      ORA #RW        ; set RW
      STA PORTA       
      ORA #E         ; toggle E on
      STA PORTA

      LDA PORTB
      AND #%10000000
      BNE lcdbusy
      LDA PORTA
      AND #E_C       ; toggle E off
      STA PORTA
      LDA #%11111111 ; Port B is ouput again
      STA DDRB
      PLA
      RTS

lcd__instruction
      JSR lcd_wait
      STA PORTB
      LDA PORTA
      AND RSWE_C     ; Clear RS/RW/E bits
      STA PORTA
      ORA #E         ; Set E bit to send instruction
      STA PORTA
      AND #E_C       ; Clear E bit
      STA PORTA
      RTS


LAB_vec
      .word ACIAin            ; byte in from simulated ACIA
      .word ACIAout           ; byte out to simulated ACIA
      .word no_load           ; null load vector for EhBASIC
      .word no_save           ; null save vector for EhBASIC

; EhBASIC IRQ support

IRQ_CODE
      PHA                     ; save A
      LDA   IrqBase           ; get the IRQ flag byte
      LSR                     ; shift the set b7 to b6, and on down ...
      ORA   IrqBase           ; OR the original back in
      STA   IrqBase           ; save the new IRQ flag byte
      PLA                     ; restore A
      RTI

; EhBASIC NMI support

NMI_CODE
      PHA                     ; save A
      LDA   NmiBase           ; get the NMI flag byte
      LSR                     ; shift the set b7 to b6, and on down ...
      ORA   NmiBase           ; OR the original back in
      STA   NmiBase           ; save the new NMI flag byte
      PLA                     ; restore A
      RTI

END_CODE

LAB_mess
      .byte $0D,$0A,"6502 EhBASIC  BE/CDO [C]old/[W]arm ?",$00
                              ; sign on string

; system vectors

      .segment "VECTORS"

      .word NMI_vec           ; NMI vector
      .word RES_vec           ; RESET vector
      .word IRQ_vec           ; IRQ vector

      .end RES_vec            ; set STArt at reset vector
      
