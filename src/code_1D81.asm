; Elite C64 disassembly / Elite : Harmless, cc-by-nc-sa 2018-2020,
; see LICENSE.txt. "Elite" is copyright / trademark David Braben & Ian Bell,
; All Rights Reserved. <github.com/Kroc/elite-harmless>
;===============================================================================
; NOTE: the segment that this code belongs to will be set by the including
;       file, e.g. "elite-original.asm" / "elite-harmless.asm"

; I think this is when the player has docked,
; it checks for potential mission offers
;
docked:                                                                 ;$1D81
;===============================================================================
        jsr _83df
        jsr _379e

        ; now the player is docked, some variables can be reset
        ; -- the cabin temperature is not reset; oversight / bug?
        lda # $00
        sta PLAYER_SPEED        ; bring player's ship to a full stop
        sta LASER_HEAT          ; complete laser cooldown
        sta ZP_66               ; reset hyperspace countdown

        ; set shields to maximum,
        ; restore energy:
        lda # $ff
        sta PLAYER_SHIELD_FRONT
        sta PLAYER_SHIELD_REAR
        sta PLAYER_ENERGY

        ldy # 44                ; wait 44 frames
        jsr wait_frames         ; -- why would this be necessary?

        ; if the galaxy is not using the original Elite seed, then the missions
        ; will not function as they rely on specific planet name / placement
        ;
.ifndef OPTION_CUSTOMSEED
        ;///////////////////////////////////////////////////////////////////////

        ; check eligibility for the Constrictor mission:
        ;-----------------------------------------------------------------------
        ; available on the first galaxy after 256 or more kills. your job is
        ; to hunt down the prototype Constrictor ship starting at Reesdice
        ;
        ; is the mission already underway or complete?
        lda MISSION_FLAGS
        and # missions::constrictor
       .bnz :+                  ; mission is underway/complete, ignore it

        lda PLAYER_KILLS_HI
        beq @skip               ; ignore mission if kills less than 256

        ; is the player in the first galaxy?
        ;
        lda PLAYER_GALAXY       ; if bit 0 is set, shifting right will cause
        lsr                     ; it to fall off the end, leaving zero;
       .bnz @skip               ; if not first galaxy, ignore mission

        ; start the Constrictor mission
        jmp _3dff

        ; is the mission complete? (both bits set)
:       cmp # missions::constrictor                                     ;$1DB5
       .bnz :+

        ; you've docked at a station, set up the 'tip' that will display in
        ; the planet info for where to find the Constrictor next
        jmp _3daf

:       ; check eligibility for Thargoid Blueprints mission             ;$1DBC
        ;-----------------------------------------------------------------------
        ; once you've met the criteria for this mission (3rd galaxy, have
        ; completed the Constrictor mission, >=1280 kills) you're presented
        ; with a message to fly to Ceerdi. Once there, you're given some
        ; top-secret blueprints which you have to get to Birera
        ;
        ; is the player in the third galaxy?
        lda PLAYER_GALAXY
        cmp # 2
        bne @skip               ; no; ignore mission

        ; player is in the third galaxy; has the player completed the
        ; Constrictor mission already? (and hasn't started blueprints mission)
        lda MISSION_FLAGS
        and # missions::constrictor | missions::blueprints
        cmp # missions::constrictor_complete
        bne :+

        ; has the player at least 1280 kills? (halfway to Deadly)
        lda PLAYER_KILLS_HI
        cmp #> 1280
       .blt @skip               ; no; skip ahead if not enough

        ; 'start' the mission: the player has to fly
        ; to Ceerdi to actually get the blueprints
        jmp mission_blueprints_begin

:       ; has the player started the blueprints mission?                ;$1DD6
        ; (and by association, completed the Constrictor mission)
        cmp # missions::constrictor_complete | missions::blueprints_begin
        bne :+

        ; is the player at Ceerdi?
        ; TODO: couldn't we use the planet index number
        ;       instead of checking co-ordinates?

        lda PSYSTEM_POS_X
        cmp # 215
        bne @skip

        lda PSYSTEM_POS_Y
        cmp # 84
        bne @skip

        jmp mission_blueprints_ceerdi

:       cmp # %00001010                                                 ;$1DEB
        bne @skip

        ; is the player at Birera?
        ; TODO: couldn't we use the planet index number
        ;       instead of checking co-ordinates?

        lda PSYSTEM_POS_X
        cmp # 63
        bne @skip

        lda PSYSTEM_POS_Y
        cmp # 72
        bne @skip

        jmp mission_blueprints_birera

.endif  ;///////////////////////////////////////////////////////////////////////

@skip:  ; check for Trumbles™ mission                                   ;$1E00
        ;
.ifndef OPTION_NOTRUMBLES
        ;///////////////////////////////////////////////////////////////////////

        ; at least 6'553.5 cash?
        lda PLAYER_CASH_pt3
        cmp # $c4               ;TODO: not sure how this works out as 6'553.5?
       .blt :+

        ; has the mission already been done?
        lda MISSION_FLAGS
        and # missions::trumbles
        bne :+

        ; initiate Trumbles™ mission
        jmp mission_trumbles

.endif  ;///////////////////////////////////////////////////////////////////////

:       jmp _88e7                                                       ;$1E11

.ifdef  OPTION_ORIGINAL
;///////////////////////////////////////////////////////////////////////////////
; the unused and incomplete debug code can be removed
; in non-original builds
;
debug_for_brk:                                                          ;$1E14
;===============================================================================
        ; set a routine to capture use of the `brk` instruction.
        ; not actually used, but present, in original Elite
        ;
        lda #< debug_brk
        sei                     ; disable interrupts
        sta KERNAL_VECTOR_BRK+0
        lda #> debug_brk
        sta KERNAL_VECTOR_BRK+1
        cli                     ; enable interrupts

        rts 

;///////////////////////////////////////////////////////////////////////////////
.endif

;===============================================================================
; Trumble™ A.I. data?
;
trumble_steps:                                                          ;$1E21
        ;-----------------------------------------------------------------------
        ; movement steps; "0, 1, -1, 0"
        .byte   $00, $01, $ff, $00

_1e25:                                                                  ;$1E25
        ;-----------------------------------------------------------------------
        .byte   $00, $00, $ff, $00

; masks for sprite MSBs?
_1e29:                                                                  ;$1E29
        .byte   %11111011, %00000100
        .byte   %11110111, %00001000
        .byte   %11101111, %00010000
        .byte   %11011111, %00100000
        .byte   %10111111, %01000000
        .byte   %01111111, %10000000

_1e35:
        ;-----------------------------------------------------------------------
        ; move Trumbles™ around the screen
        ;
        lda ZP_A3               ; "move counter"?
        and # %00000111         ; modulo 8 (0-7)
        cmp TRUMBLES_ONSCREEN   ; number of Trumble™ sprites on-screen
       .blt :+

        jmp roll_pitch

        ; take the counter 0-7 and multiply by 2
        ; for use in a table of 16-bit values later
:       asl                                                             ;$1E41
        tay 

.ifdef  OPTION_ORIGINAL
        ;///////////////////////////////////////////////////////////////////////
        ; turn the I/O area on to manage the sprites
        lda # C64_MEM::IO_ONLY
        jsr set_memory_layout
.else   ;///////////////////////////////////////////////////////////////////////
        ; optimisation for changing the memory map,
        ; with thanks to: <http://www.c64os.com/post?p=83>
        inc CPU_CONTROL
.endif  ;///////////////////////////////////////////////////////////////////////

        ; should the Trumbles™ change direction?
        ;
        jsr get_random_number   ; select a random number
        cmp # 235               ; is it > 234 (about 8% probability)
       .blt @move               ; no, just keep moving

        ; pick a direction for the Trumble™
        ;
        ; select an X direction:
        ; 50% chance stay still, 25% go left, 25% go right
        and # %00000011         ; random number modulo 4 (0-3)
        tax                     ; choice 1-4
        lda trumble_steps, x    ; pick a direction, i.e. 0, 1 or -1
        sta TRUMBLES_MOVE_X, y  ; set the Trumble™'s X direction

        lda _1e25, x
        sta VAR_0521, y

        ; select a Y direction:
        ; 50% chance stay still, 25% go up, 25% go down
        jsr get_random_number   ; pick a new random number
        and # %00000011         ; modulo 4 (0-3)
        tax                     ; choice 1-4
        lda trumble_steps, x    ; pick a direction, i.e. 0, 1 or -1
        sta TRUMBLES_MOVE_Y, y  ; set the Trumble™'s Y direction

@move:                                                                  ;$1E6A
        ;-----------------------------------------------------------------------
        lda _1e29, y
        and VIC_SPRITES_X
        sta VIC_SPRITES_X

        ; move the Trumble™ sprite vertically:
        lda VIC_SPRITE2_Y, y    ; current hardware sprite Y-position
        clc                     ; math!
        adc TRUMBLES_MOVE_Y, y  ; add the Trumble™'s Y direction
        sta VIC_SPRITE2_Y, y    ; update the hardware sprite

        ; move the Trumble™ sprite horizontally:
        clc 
        lda VIC_SPRITE2_X, y    ; current hardware sprite X-position (0-255)
        adc TRUMBLES_MOVE_X, y  ; add the Trumble™'s X direction
        sta ZP_VAR_T            ; put aside whilst we handle the MSB (256-319) 

        lda VAR_0531, y
        adc VAR_0521, y
        bpl :+

        lda # $48               ;=72 / %01001000
        sta ZP_VAR_T            ; '328'?

        lda # $01
:       and # %00000001                                                 ;$1E94
        beq :+

        lda ZP_VAR_T
        cmp # $50               ;=80 / %10000000
        lda # $01
        bcc :+

        lda # $00
        sta ZP_VAR_T

:       sta VAR_0531, y                                                 ;$1EA4
        beq :+

        ; MSBs?
        lda _1e29+1, y
        ora VIC_SPRITES_X       ; combine with current hardware sprite MSBs
        sei                     ; disable interrupts whilst repositioning
        sta VIC_SPRITES_X       ; update the 8 hardware sprite MSBs
:       lda ZP_VAR_T                                                    ;$1EB3
        sta VIC_SPRITE2_X, y
        cli                     ; re-enable interrupts

.ifdef  OPTION_ORIGINAL
        ;///////////////////////////////////////////////////////////////////////
        ; turn I/O off, go back to 64K RAM
        lda # C64_MEM::ALL
        jsr set_memory_layout
.else   ;///////////////////////////////////////////////////////////////////////
        ; optimisation for changing the memory map,
        ; with thanks to: <http://www.c64os.com/post?p=83>
        dec CPU_CONTROL
.endif  ;///////////////////////////////////////////////////////////////////////

        jmp roll_pitch


_1ec1:                                                                  ;$1EC1
;===============================================================================
; main cockpit-view game-play loop perhaps?
; (handles many key presses)
;-------------------------------------------------------------------------------
        ; seed the random-number-generator:
        lda polyobj_00          ; TODO: why this byte?
        sta ZP_GOATSOUP_pt1

.ifndef OPTION_NOTRUMBLES
        ;///////////////////////////////////////////////////////////////////////

        ; are there any Trumbles™ on-screen?
        lda TRUMBLES_ONSCREEN   ; number of Trumble™ sprites on-screen
       .bze roll_pitch          ; =0; don't process Trumbles™

        ; process Trumbles™
        ; (move them about, breed them)
        jmp _1e35

.endif  ;///////////////////////////////////////////////////////////////////////

roll_pitch:                                                             ;$1ECE
        ;-----------------------------------------------------------------------
        ; take the roll amount and prepare it for use in the 3D math:
        ;
        ldx JOY_ROLL            ; current roll amount (from joy/key input)
        jsr dampen_toward_zero  ; apply damping?
        jsr dampen_toward_zero  ; apply damping?
        txa                     ; transfer roll amount back to A

        ; elite actually rotates the universe around the player(!),
        ; therefore rolling to the right means rolling everything else
        ; to the left which is why we do some sign flipping here whilst
        ; preparing the angle. thanks goes to Mark Moxon's BBC disassembly
        ; for this insight

        ; get the absolute value and some additional values useful
        ; for the math, including an inverted copy of the sign
        ;
        eor # %10000000         ; flip the sign bit
        tay                     ; (put aside)
        and # %10000000         ; extract just the sign bit
        sta ZP_ROLL_SIGN        ; store as our "direction of roll"

        ; (write back the updated original roll value, after dampening;
        ;  this happens not to be related to the above few instructions)
        stx JOY_ROLL
        
        eor # %10000000         ; flip the sign bit
        sta ZP_INV_ROLL_SIGN    ; keep inverse roll direction

        tya                     ; retrieve our roll amount, with flipped sign
        bpl :+                  ; if positive, skip over

        ; roll amount is negative, make it positive (absolute)
        ; via a 2's complement (flip all bits and add 1)
        eor # %11111111
        clc 
        adc # $01

        ; we now have the absolute roll amount
        ;
:       lsr                     ; divide by 2,                           ;$1EEE
        lsr                     ; divide by 4
        cmp # $08               ;?
       .bge :+
        lsr 

:       sta ZP_ROLL_MAGNITUDE                                           ;$1EF5
        ora ZP_ROLL_SIGN        ; add sign
        sta ZP_ALPHA            ; put aside for use in the matrix math

        ; process pitch amount:
        ;-----------------------------------------------------------------------
        ldx JOY_PITCH           ; current pitch amount (from joy/key input)
        jsr dampen_toward_zero  ; apply damping (if enabled)
        txa                     ; transfer pitch amount back to A

        eor # %10000000         ; flip the sign-bit
        tay                     ; put aside for later
        and # %10000000         ; extract just the sign bit
        
        ; (write back the updated original pitch value, after dampening;
        ;  this happens not to be related to the above few instructions)
        stx JOY_PITCH
        
        sta ZP_INV_PITCH_SIGN
        eor # %10000000
        sta ZP_PITCH_SIGN       ; store as our "direction of pitch"
        tya 
        bpl :+
        eor # %11111111
:       adc # $04                                                       ;$1F15
        lsr 
        lsr 
        lsr 
        lsr 
        cmp # $03
        bcs :+
        lsr 

:       sta ZP_PITCH_MAGNITUDE                                          ;$1F20
        ora ZP_PITCH_SIGN
        sta ZP_BETA             ; put aside for the matrix math

        ; TODO: this section processes a number of key presses;
        ;       could we skip this when no keys are pressed by
        ;       marking a 'no keys' flag?
main_keys:
        ;=======================================================================
        ; accelerate?
        ;-----------------------------------------------------------------------
        lda key_accelerate      ; is accelerate being held?
       .bze :+                  ; if not, continue

        lda PLAYER_SPEED        ; current speed
        cmp # 40                ; are we at maximum speed?
        bcs :+

        inc PLAYER_SPEED        ; increase player's speed

:       ; decelerate?                                                   ;$1F33
        ;-----------------------------------------------------------------------
        lda key_decelerate      ; is decelerate being held?
       .bze :+                  ; if not, continue

        dec PLAYER_SPEED        ; reduce player's speed
       .bnz :+                  ; still above zero?
        inc PLAYER_SPEED        ; if zero, set to 1

:       ; disarm missile?                                               ;$1F3E
        ;-----------------------------------------------------------------------
        lda key_missile_disarm  ; is disarm missile key being pressed?
        and PLAYER_MISSILES     ; does the player have any missiles?
       .bze :+                  ; no? skip ahead

        ; untarget missile and change colour of the missile-block on the HUD
        ldy # .color_nybble( GREEN, HUD_COLOUR )
        jsr untarget_missile

.ifdef  FEATURE_AUDIO
        ;///////////////////////////////////////////////////////////////////////
        ldy # $06
        jsr play_sfx
.endif  ;///////////////////////////////////////////////////////////////////////

        lda # $00               ; set loaded missile as disarmed ($00)
        sta PLAYER_MISSILE_ARMED

        ; target missile?
        ;-----------------------------------------------------------------------
:       lda ZP_MISSILE_TARGET   ; is there a missile target?            ;$1F55
        bpl :+                  ; if yes, skip, cannot re-target

        lda key_missile_target  ; target missile key pressed?
       .bze :+                  ; no, continue...

        ldx PLAYER_MISSILES     ; does the player have any missiles?
       .bze :+                  ; if missiles are zero, skip

        ; set missile armed flag
        ; (A = $FF from `key_missile_target`)
        sta PLAYER_MISSILE_ARMED
        ; update the colour of the HUD missile indicator. note that X is
        ; the missile number which chooses which missile block to colour
        ldy # .color_nybble( ORANGE, HUD_COLOUR )
        jsr update_missile_indicator

        ; fire missile?
        ;-----------------------------------------------------------------------
:       lda key_missile_fire    ; fire missile key held?                ;$1F6B
       .bze :+                  ; no, skip ahead

        lda ZP_MISSILE_TARGET   ; check the missile target...
        ; if no target, skip ahead. this skips over most of the
        ; remaining key-press checks and is likely an oversight
        bmi :++++++             ;(=$1FC2)
        
        jsr fire_missile

        ; energy bomb?
        ;-----------------------------------------------------------------------
:       lda key_bomb            ; energy bomb key held?                 ;$1F77
       .bze :+                  ; no, skip ahead

        ; enable the energy bomb; if present, it's value should be $FF,
        ; so shifting left makes it %11111110. if the player does not
        ; have a bomb (=$00), the value will remain zero
        ;
        asl PLAYER_EBOMB        ; activate the bomb
        beq :+                  ; did that work? skip if no bomb present

        ; create a 'screen glitch' effect by changing the hi-res portion
        ; of the screen to multi-colour when the bomb goes off(?)
        ldy # vic_screen_ctl2::unused | vic_screen_ctl2::multicolor
        sty interrupt_screenmode1

.ifdef  FEATURE_AUDIO
        ;///////////////////////////////////////////////////////////////////////
        ldy # $0d               ; e-bomb sound?
        jsr play_sfx
.endif  ;///////////////////////////////////////////////////////////////////////

        ; turn docking computer off?
        ;-----------------------------------------------------------------------
:       lda key_docking_off     ; docking-computer off pressed?         ;$1F8B
       .bze :+                  ; no? skip ahead

        lda # $00               ; $00 = OFF
        sta DOCKCOM_STATE       ; turn docking computer off

        jsr stop_sound          ; stop all sound playing

        ; activate escape pod?
        ;-----------------------------------------------------------------------
:       lda key_escape_pod      ; escape pod key pressed?               ;$1F98
        and PLAYER_ESCAPEPOD    ; does the player have an escape pod?
       .bze :+                  ; no? keep moving

        lda IS_WITCHSPACE       ; is the player stuck in witchspace?
       .bnz :+                  ; yes? cannot eject in witchspace!
                                ; TODO: play sound / display warning?

        jmp eject_escapepod     ; eject the escpae pod!

        ; quick-jump?
        ;-----------------------------------------------------------------------
:       lda key_jump            ; quick-jump key pressed?               ;$1FA8
       .bze :+                  ; no? skip ahead

        jsr do_quickjump        ; handle the quick-jump

        ; activate E.C.M.?
        ;-----------------------------------------------------------------------
:       lda key_ecm             ; E.C.M. key pressed?                   ;$1FB0
        and PLAYER_ECM          ; does the player have an E.C.M.?
       .bze :+                  ; no? skip ahead

        lda ECM_COUNTER         ; is any ECM already active? (ours or enemy's!)
       .bnz :+                  ; yes? skip

        dec ECM_STATE           ; underflow our ECM state from $00 to $FF
        jsr engage_ecm          ; handle ECM effects...

        ; turn docking computer on?
        ;-----------------------------------------------------------------------
:       lda key_docking_on      ; key for docking computer pressed?     ;$1FC2
        and PLAYER_DOCKCOM      ; does the player have a docking computer?
       .bze :+                  ; no, skip

;;      eor polyobj_01+PolyObject::attack
        eor joy_down            ; TODO: combine with down key state???
       .bze :+

        sta DOCKCOM_STATE       ; turn docking computer on (A = $FF)
        jsr _9204               ; play docking computer music

        ; handle lasers:
        ;-----------------------------------------------------------------------
:       lda # $00                                                       ;$1FD5
        sta ZP_7B               ; laser-power per pulse?
        sta ZP_SPEED_LO         ; dust-speed low-byte?

        ; divide player speed by 4; used as part of moving dust
        ; TODO: should this be cached and only re-calced on speed change?
        ;
        lda PLAYER_SPEED        ; current player speed
        lsr                     ; divide speed by 2
        ror ZP_SPEED_LO         ; ripple down to the result, lo-byte
        lsr                     ; divide speed by 2, again
        ror ZP_SPEED_LO         ; ripple down to the result, lo-byte
        sta ZP_SPEED_HI         ; store result hi-byte

        ; check if the laser is over-heated
        lda VAR_0487            ; laser cool-off counter?
        bne @ships              ; skip ahead if laser is cooling down

        lda joy_fire            ; is fire-key pressed?
        beq @ships              ; no? skip ahead

        lda LASER_HEAT          ; check current laser heat
        cmp # $f2               ; laser temp >= 242?
        bcs @ships              ; don't fire if too hot

        ; is there a laser mounted on this direction?
        ; TODO: shouldn't we check for this first??
        ;
        ldx COCKPIT_VIEW        ; current facing direction
        lda PLAYER_LASERS, x    ; get type of laser mounted here
        beq @ships              ; if zero, no laser, skip ahead

        pha                     ; put aside laser type
        and # %01111111
        sta ZP_7B               ;?
        sta VAR_0484            ;?

.ifdef  FEATURE_AUDIO
        ;///////////////////////////////////////////////////////////////////////
        ldy # $00
        pla
        pha                     ; (redo flags?)
        bmi :++
        cmp # $32
        bne :+                  ; (BNE to another BNE! should be `bne @201d`)
        ldy # $0c
:       bne @201d                                                       ;$2012
:       cmp # $97                                                       ;$2014
        beq @201b

        ldy # $0a               ; laser sound #1?
        ; (this causes the next instruction to become a meaningless `bit`
        ;  instruction, a very handy way of skipping without branching)
       .bit
@201b:  ldy # $0b               ; laser sound #2?                       ;$201B
@201d:  jsr play_sfx                                                    ;$201D
.endif  ;///////////////////////////////////////////////////////////////////////

        jsr shoot_lasers        ; pew-pew!
        
        pla                     ; retrieve laser type?
        bpl :+
        lda # $00               ; instant cool-down?
:       and # %11111010                                                 ;$2028
        sta VAR_0487            ; update cool-down state?

        ; process ships?
        ;-----------------------------------------------------------------------
@ships: ldx # $00               ; begin with ship-slot 0                ;$202D


process_ship:                                                           ;$202F
;===============================================================================
; in:   X       ship-slot index
;-------------------------------------------------------------------------------
        stx ZP_9D               ; set ship-slot to inspect
        lda SHIP_SLOTS, x       ; is that a ship in your slot?
        bne :+                  ; if so, process it
        jmp _21fa               ; no more ships to process,
                                ; you're just happy to see me

:       sta ZP_A5               ; put ship type aside                   ;$2039
        jsr get_polyobj_addr    ; look up the ship's personal data

        ; copy the given PolyObject to
        ; the working space in zero page
        ;
        ; TODO: we may be able to delay this copy until later in the logic
        ;       i.e. we might not need the ZP polyObject until the ship moves
        ;
;;.ifdef  OPTION_ORIGINAL
        ;///////////////////////////////////////////////////////////////////////
        ;                                 bytes cycles
        ldy # .sizeof(PolyObject)-1     ;  2     2
        ;-------------------------------;---------------------------------------
:       lda [ZP_POLYOBJ_ADDR], y        ; +2=4   5=5                    ;$2040
        sta ZP_POLYOBJ, y               ; +2=6  +5=10
        dey                             ; +1=7  +2=12
        bpl :-                          ; +2=9  +3=15 (+2 for !bpl)
        ;-------------------------------;---------------------------------------
        ;                         loop: ;       *37=554
        ;                        total: ;    9  556
;;.else   ;/////////////////////////////////////////////////////////////////////
;;        ; TODO: this won't fit into this segment in the non-hiram config
;;        ldy # 0                       ; 2     2
;;        .repeat $23, I
;;        lda [ZP_POLYOBJ_ADDR], y      ; 2     5=5
;;        sta ZP_POLYOBJ + I            ; 2     3=8
;;        iny                           ; 1     2=10
;;        .endrepeat                    ; 5*36  10*36 (+2) = 362 cycles
;;        lda [ZP_POLYOBJ_ADDR], y      ; 2     5=367
;;        sta ZP_POLYOBJ + $24          ; 2     3=370
;;                                      ;=186 bytes!
;;.endif  ;/////////////////////////////////////////////////////////////////////

        ; TODO: if we use LDX instead, we can preserve the ship-type through
        ;       this logic and do away with a number of additional LDA's?
        ;
        lda ZP_A5               ; get ship type back
        bmi @move               ; if sun / planet, skip over

        asl                     ; multiply by 2 for table lookup
        tay                     ; use as an index
        lda hull_pointers-2, y  ; look up the hull data, lo-byte
        sta ZP_HULL_ADDR_LO
        lda hull_pointers-1, y  ; look up the hull data, hi-byte
        sta ZP_HULL_ADDR_HI

        ; e-bomb explodes ship:
        ;-----------------------------------------------------------------------
        ; is the e-bomb active? (bit 7 set)
        lda PLAYER_EBOMB        ; check e-bomb state
        bpl @move               ; inactive, skip over

        ; space station? -- cannot be destroyed by e-bomb
        cpy # HULL_COREOLIS *2
        beq @move

        ; thargoid? -- also cannot be e-bombed
        cpy # HULL_THARGOID *2
        beq @move

        ; constrictor, cougar & dodo-station? -- also cannot be e-bombed
        ; WARN: this assumes any ID of constrictor or above are valid!
        cpy # HULL_CONSTRICTOR *2
        bcs @move

        ; make ship disappear?
        ;
        lda ZP_POLYOBJ_STATE    ; get the ship's state
        and # state::debris
       .bnz @move

        ; set bit 7 to indicate the ship is exploding
        ;
        asl ZP_POLYOBJ_STATE    ; push bit 7 off
        sec                     ; set carry and...
        ror ZP_POLYOBJ_STATE    ; ...shift the carry into bit 7

        ldx ZP_A5               ; retrieve ship-type again?
        jsr _a7a6               ; kill ship?

        ; move the ship forward:
        ;-----------------------------------------------------------------------
@move:  jsr _a2a0               ; move ship?                            ;$2079

        ; copy the zero-page PolyObject back to its storage
        ; TODO: unroll this in hiram config
        ldy # .sizeof(PolyObject) - 1
:       lda ZP_POLYOBJ, y                                               ;$207E
        sta [ZP_POLYOBJ_ADDR], y
        dey 
        bpl :-

        ; if the ship is exploding, or at a medium distance(?)
        ; then skip the next bit
        lda ZP_POLYOBJ_STATE
        and # state::exploding | state::debris
.ifdef  OPTION_ORIGINAL
        ;///////////////////////////////////////////////////////////////////////
        jsr _87b1               ; combine check with medium distance
.else   ;///////////////////////////////////////////////////////////////////////
        ora ZP_POLYOBJ_XPOS_HI  ; there's really no need for a JSR for this
        ora ZP_POLYOBJ_YPOS_HI
        ora ZP_POLYOBJ_ZPOS_HI
.endif  ;///////////////////////////////////////////////////////////////////////
        bne @20e0               

        ; check the near distance(?)
        lda ZP_POLYOBJ_XPOS_LO
        ora ZP_POLYOBJ_YPOS_LO
        ora ZP_POLYOBJ_ZPOS_LO
        bmi @20e0               ; TODO: too far, or is this about direction?

        ldx ZP_A5               ; sun or planet?
        bmi @20e0               ; yes, skip

        cpx # HULL_COREOLIS     ; space station?
        beq @20e3               ; yes, handle space-station behaviour

        and # %11000000
        bne @20e0

        cpx # HULL_MISSILE      ; is it a missile?
        beq @20e0               ; yes, skip

        lda PLAYER_SCOOP        ; have fuel scoop?
        and ZP_POLYOBJ_YPOS_SIGN; TODO: near sun(?)
        bpl _2122

        cpx # HULL_CANNISTER    ; is this a cargo cannister?
        beq @20c0

        ; not a cargo cannister:
        ;
        ; read scoop data from the hull
        ldy # Hull::scoop_debris
        lda [ZP_HULL_ADDR], y
        lsr                     ; down shift the top-nybble
        lsr                     ; into the bottom nybble
        lsr                     ; (cargo-data is held in the top-nybble,
        lsr                     ;  debris-data in the low-nybble)
        beq _2122               ; if zero, cannot be scooped?

        ; TODO: this would imply that the `scoop_debris`-data in the hulls
        ;       would need to be generated from HULL_* constants
        ;
        adc # $01               ; select type of cargo(?)
        bne @20c5               ; (always branches)

        ; scooped cargo:
        ;-----------------------------------------------------------------------
@20c0:  jsr get_random_number   ; choose a random type of cargo         ;$20C0
        and # %00000111         ; limit to 0-7

@20c5:  jsr _6a00               ; count cargo?                          ;$20C5
        ldy # $4e               ; TODO: ?
        bcs _2110               ; cargo full

        ldy VAR_04EF            ; type of cargo
        adc VAR_CARGO, y        ; add to cargo
        sta VAR_CARGO, y
        tya

        ; print the name of the cargo 
.import TXT_FLIGHT_FOOD:direct
        adc # TXT_FLIGHT_FOOD
        jsr _900d

        ; mark cannister for removal:
        ; (set bit 7)
        asl ZP_POLYOBJ_BEHAVIOUR
        sec 
        ror ZP_POLYOBJ_BEHAVIOUR

@20e0:  jmp _2131                                                       ;$20E0

        ; space-station:
        ;-----------------------------------------------------------------------
        ; is the station hostile?
@20e3:  lda polyobj_01 + PolyObject::behaviour                          ;$20E3
        and # behaviour::angry  ; check the angry flag
       .bnz dock_fail           ; cannot dock!

        ; are we docking?
        ;
        lda ZP_POLYOBJ_M0x2_HI  ; check rotation of station?
        cmp # $d6
        bcc dock_fail

        jsr _8c7b               ; distance from planet?
        lda ZP_VAR_X2
        cmp # $59
        bcc dock_fail

        lda ZP_POLYOBJ_M1x0_HI  ; rotation of slot?
        and # %01111111         ; (remove sign)
        cmp # $50
        bcc dock_fail

dock_ok:                                                                ;$2101
        ;-----------------------------------------------------------------------
        ; docking successful!
        ; NOTE: escape capsule jumps here to return you to the station
        ;
        jsr stop_sound          ; stop all sound playing
        jmp docked              ; handle docked screen
        
dock_fail:                                                              ;$2107
        ;-----------------------------------------------------------------------
        ; docking fail!
        ;
        lda PLAYER_SPEED        ; check approach speed
        cmp # $05               ; going slow?
        bcc _211a               ; slow; take damage
        jmp _87d0               ; fast; explode

_2110:                                                                  ;$2110
        ;-----------------------------------------------------------------------
.ifdef  FEATURE_AUDIO
        ;///////////////////////////////////////////////////////////////////////
        jsr play_sfx_03
.endif  ;///////////////////////////////////////////////////////////////////////

        ; set top-bit of ship state? (is exploding)
        asl ZP_POLYOBJ_STATE
        sec 
        ror ZP_POLYOBJ_STATE
        bne _2131               ; (always branhces)

_211a:  ; player takes damage:                                          ;$211A
        ;-----------------------------------------------------------------------
        lda # $01               ; slow down
        sta PLAYER_SPEED
        lda # $05               ; take '5' damage
        bne _212b               ; (always branches)

_2122:                                                                  ;$2122
        ;-----------------------------------------------------------------------
        ; set state bit 7 (is exploding)
        asl ZP_POLYOBJ_STATE
        sec 
        ror ZP_POLYOBJ_STATE
        
        lda ZP_POLYOBJ_ENERGY
        sec 
        ror 
_212b:                                                                  ;$212B
        jsr _7bd2               ; take damage?

.ifdef  FEATURE_AUDIO
        ;///////////////////////////////////////////////////////////////////////
        jsr play_sfx_03
.endif  ;///////////////////////////////////////////////////////////////////////

_2131:                                                                  ;$2131
        ; should the ship be removed?
        lda ZP_POLYOBJ_BEHAVIOUR
        bpl :+
        jsr _b410

:       lda ZP_SCREEN           ; are we in the cockpit-view?           ;$2138
       .bnz _21ab               ; no? skip ahead

        jsr _a626
        jsr _363f
        bcc _21a8

        lda PLAYER_MISSILE_ARMED
        beq :+

.ifdef  FEATURE_AUDIO
        ;///////////////////////////////////////////////////////////////////////
        jsr play_sfx_05         ; beep?
.endif  ;///////////////////////////////////////////////////////////////////////
        ldx ZP_9D               ; missile target?
        ldy # .color_nybble( RED, HUD_COLOUR )
        jsr target_missile

:       lda ZP_7B               ; laser power?                          ;$2153
        beq _21a8               ; no laser, skip onwards

        ldx # $0f
        jsr _a7e9

        lda ZP_A5               ; things we've shot with laser?
        cmp # HULL_COREOLIS
        beq _21a3
        cmp # HULL_CONSTRICTOR
        bcc _2170

        lda ZP_7B               ; laser strength?
        cmp # $17
        bne _21a3
        lsr ZP_7B
        lsr ZP_7B
_2170:                                                                  ;$2170
        lda ZP_POLYOBJ_ENERGY   ; ship's energy-level
        sec 
        sbc ZP_7B
        bcs _21a1

        ; explode the ship
        asl ZP_POLYOBJ_STATE    ; remove bit 7
        sec                     ; take a 1 from the bit bucket
        ror ZP_POLYOBJ_STATE    ; shift it into bit 7

        lda ZP_A5
        cmp # HULL_ASTEROID
        bne _2192

        lda ZP_7B               ; mining laser?
        cmp # $32
        bne _2192

        jsr get_random_number
        ldx # HULL_SPLINTER     ; spawn a rock splinter
        and # %00000011
        jsr _2359
_2192:                                                                  ;$2192
        ldy # HULL_PLATE
        jsr _234c
        ldy # HULL_CANNISTER
        jsr _234c

        ldx ZP_A5
        jsr _a7a6               ; kill ship?
_21a1:                                                                  ;$21A1
        sta ZP_POLYOBJ_ENERGY
_21a3:                                                                  ;$21A3
        lda ZP_A5
        jsr _36c5               ; make hostile?
_21a8:                                                                  ;$21A8
        jsr draw_ship

_21ab:                                                                  ;$21AB
        ldy # PolyObject::energy
        lda ZP_POLYOBJ_ENERGY
        sta [ZP_POLYOBJ_ADDR], y

        lda ZP_POLYOBJ_BEHAVIOUR
        bmi _21e2

        lda ZP_POLYOBJ_STATE
        bpl _21e5               ; bit 7 set?

        and # state::debris
        beq _21e5

        lda ZP_POLYOBJ_BEHAVIOUR
        and # behaviour::police
        ora PLAYER_LEGAL
        sta PLAYER_LEGAL
        lda VAR_048B
        ora IS_WITCHSPACE
        bne _21e2

        ldy # Hull::bounty      ;=$0A: (bounty lo-byte)
        lda [ZP_HULL_ADDR], y
        beq _21e2

        tax 
        iny                     ;=$0B: (bounty hi-byte)
        lda [ZP_HULL_ADDR], y
        tay 
        jsr _7481
        lda # $00
        jsr _900d
_21e2:                                                                  ;$21E2
        jmp _829a

        ;-----------------------------------------------------------------------

_21e5:                                                                  ;$21E5
        lda ZP_A5
        bmi _21ee
        jsr _87a4
        bcc _21e2
_21ee:                                                                  ;$21EE
        ; update the poly-object's stored state
        ; with the current working state
        ldy # PolyObject::state
        lda ZP_POLYOBJ_STATE
        sta [ZP_POLYOBJ_ADDR], y

        ldx ZP_9D
        inx 
        jmp process_ship

        ;-----------------------------------------------------------------------

_21fa:                                                                  ;$21FA
        lda PLAYER_EBOMB        ; player has energy bomb?
        bpl _2207
        asl PLAYER_EBOMB
        bmi _2207
        jsr _2367
_2207:                                                                  ;$2207
        lda ZP_A3               ; move counter?
        and # %00000111
        bne _227a

        ldx PLAYER_ENERGY
        bpl _2224

        ldx PLAYER_SHIELD_REAR
        jsr _7b61
        stx PLAYER_SHIELD_REAR

        ldx PLAYER_SHIELD_FRONT
        jsr _7b61
        stx PLAYER_SHIELD_FRONT
_2224:                                                                  ;$2224
        sec 
        lda VAR_04C4            ; energy charge rate?
        adc PLAYER_ENERGY
        bcs _2230
        sta PLAYER_ENERGY
_2230:                                                                  ;$2230
        lda IS_WITCHSPACE
        bne _2277

        lda ZP_A3               ; move counter?
        and # %00011111
        bne _2283

        ; NOTE: `.loword` is needed here to force a 16-bit
        ;       parameter size and silence an assembler warning
        lda .loword( SHIP_TYPES + HULL_COREOLIS )
        bne _2277

        tay 
        jsr _2c50
        bne _2277

        ; copy some of the PolyObject data to zeropage:
        ;
        ; the X/Y/Z position of the PolyObject
        ; (these are not addresses, but they are 24-bit)
        ;
        ; $09-$0B:      xpos            .faraddr
        ; $0C-$0E:      ypos            .faraddr
        ; $0F-$11:      zpos            .faraddr
        ;
        ; a 3x3 rotation matrix?
        ;
        ; $12-$13:      m0x0            .word
        ; $14-$15:      m0x1            .word
        ; $16-$17:      m0x2            .word
        ; $18-$19:      m1x0            .word
        ; $1A-$1B:      m1x1            .word
        ; $1C-$1D:      m1x2            .word
        ; $1E-$1F:      m2x0            .word
        ; $20-$21:      m2x1            .word
        ; $22-$23:      m2x2            .word
        ;
        ; $24:          speed           .byte
        ; $25:          acceleration    .byte
        ;
        ; number of bytes to copy:
        ; (up to, and including, the `acceleration` property)
        ldx # PolyObject::acceleration + .sizeof(PolyObject::acceleration)-1

:       lda polyobj_00, x       ;=$F900                                 ;$2248
        sta ZP_POLYOBJ, x       ;=$09
        dex 
        bpl :-

        inx 
        ldy # $09
        jsr _2c2d
        bne _2277

        ldx # $03
        ldy # $0b
        jsr _2c2d
        bne _2277
        ldx # $06
        ldy # $0d
        jsr _2c2d
        bne _2277
        lda # $c0
        jsr _87a6
        bcc _2277

        jsr wipe_sun
        jsr _7c24
_2277:                                                                  ;$2277
        jmp _231c

        ;-----------------------------------------------------------------------

_227a:                                                                  ;$227A
        lda IS_WITCHSPACE
        bne _2277

        lda ZP_A3               ; move counter?
        and # %00011111
_2283:                                                                  ;$2283
        cmp # $0a
        bne _22b5
        lda # $32
        cmp PLAYER_ENERGY
        bcc _2292
        asl 
        jsr _900d
_2292:                                                                  ;$2292
        ldy # $ff
        sty VAR_06F3
        iny 
        jsr _2c4e
        bne _231c
        jsr _2c5c
        bcs _231c
        sbc # $24
        bcc _22b2
        sta ZP_VAR_R
        jsr square_root
        lda ZP_VAR_Q
        sta VAR_06F3
        bne _231c
_22b2:                                                                  ;$22B2
        jmp _87d0

_22b5:                                                                  ;$22B5
        ;-----------------------------------------------------------------------
        cmp # $0f
        bne _22c2

        lda DOCKCOM_STATE
       .bze _231c

        lda # $7b
        bne _2319               ; (always branches)

_22c2:                                                                  ;$22C2
        ;-----------------------------------------------------------------------
        cmp # $14
        bne _231c

        lda # $1e
        sta CABIN_HEAT

        ; NOTE: `.loword` is needed here to force a 16-bit
        ;       parameter size and silence an assembler warning
        lda .loword( SHIP_TYPES + HULL_COREOLIS )
        bne _231c

        ldy # .sizeof(PolyObject)
        jsr _2c50
       .bnz _231c

        jsr _2c5c

        eor # %11111111
        adc # $1e
        sta CABIN_HEAT
        bcs _22b2

        cmp # $e0               ; high temperature?
        bcc _231c
        cmp # $f0               ; critical temperature?
        bcc _2303

.ifndef OPTION_NOTRUMBLES
        ;///////////////////////////////////////////////////////////////////////
.ifdef  OPTION_ORIGINAL
        ;///////////////////////////////////////////////////////////////////////
        ; turn the I/O area on to manage the sprites
        lda # C64_MEM::IO_ONLY
        jsr set_memory_layout
.else   ;///////////////////////////////////////////////////////////////////////
        ; optimisation for changing the memory map,
        ; with thanks to: <http://www.c64os.com/post?p=83>
        inc CPU_CONTROL
.endif  ;///////////////////////////////////////////////////////////////////////

        ; kill the Trumbles™ from over-heating?
        ; remove their sprites on screen
        lda VIC_SPRITE_ENABLE
        and # %00000011
        sta VIC_SPRITE_ENABLE

.ifdef  OPTION_ORIGINAL
        ;///////////////////////////////////////////////////////////////////////
        ; turn off I/O, go back to 64K RAM
        lda # C64_MEM::ALL
        jsr set_memory_layout
.else   ;///////////////////////////////////////////////////////////////////////
        ; optimisation for changing the memory map,
        ; with thanks to: <http://www.c64os.com/post?p=83>
        dec CPU_CONTROL
.endif  ;///////////////////////////////////////////////////////////////////////

        ; halve the number of Trumbles™
        lsr PLAYER_TRUMBLES_HI  ; divide the top 8-bits by two, with carry out
        ror PLAYER_TRUMBLES_LO  ; divide bottom 8-bits by two, with carry in
.endif  ;///////////////////////////////////////////////////////////////////////

_2303:                                                                  ;$2303
        lda PLAYER_SCOOP        ; does the player have a fuel-scoop?
       .bze _231c               ; skip over if not

        lda ZP_SPEED_HI
        lsr 
        adc PLAYER_FUEL
        cmp # $46
        bcc :+
        lda # $46                                                                  
:       sta PLAYER_FUEL                                                 ;$2314

        lda # $a0
_2319:                                                                  ;$2319
        jsr _900d
_231c:                                                                  ;$231C
        lda VAR_0484
        beq _2330
        lda VAR_0487
        cmp # $08
        bcs _2330
        jsr _3cfa
        lda # $00
        sta VAR_0484
_2330:                                                                  ;$2330
        lda ECM_STATE           ; is our ECM enabled?
        beq _233a

        jsr _7b64
        beq _2342
_233a:                                                                  ;$233A
        lda ECM_COUNTER         ; is an ECM already active?
        beq _2345
        dec ECM_COUNTER
        bne _2345
_2342:                                                                  ;$2342
        jsr _a786
_2345:                                                                  ;$2345
        lda ZP_SCREEN           ; are we in the cockpit-view?
       .bnz _2366               ; (no? skip over)

        jmp move_dust


_234c:                                                                  ;$234C
;===============================================================================
; in:   Y       ship-type
;-------------------------------------------------------------------------------
        jsr get_random_number   ; choose random number,
        bpl _2366               ; 50/50

        tya 
        tax 
        ldy # Hull::scoop_debris
        and [ZP_HULL_ADDR], y
        and # %00001111

_2359:                                                                  ;$2359
;===============================================================================
; in:   A       ?
;-------------------------------------------------------------------------------
        sta ZP_AA
        beq _2366               ; zero-flag will not be set by STA!

:       lda # $00                                                       ;$235D
        jsr _370a               ; NOTE: spawns ship-type in X
        
        dec ZP_AA
        bne :-

_2366:  rts                                                             ;$2366


_2367:                                                                  ;$2367
;===============================================================================
        lda # %11000000
        sta interrupt_screenmode1

        lda # $00
        sta _a8e6

        rts 
