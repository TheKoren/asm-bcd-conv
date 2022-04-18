; -----------------------------------------------------------
; Mikrokontroller alapú rendszerek házi feladat
; Készítette: Koren Zoltán
; Neptun code: HOTQM1
; Feladat leírása:
;		Regiszterekben található 16 bites elõjeles egész átalakítása 5 db BCD kódú számmá + elõjellé.
;		Az eredményt 3 regiszterben kapjuk vissza: az elsõben a legfelsõ bit az elõjel, az alatta lévõ
;		3 bit 0, ez alatt a legmagasabb helyiértékû digit. A második regiszterben a következõ két digit,
;		a harmadikban a legkisebb helyiértékû két digit. Bemenet: az átalakítandó szám 2 regiszterben,
;		kimenet az átalakított szám 3 regiszterben.
;
;-------------------------------------------------------------
;Kiegészítés:
;		A 16 bites bináris szám az R0(alsó 8 bit), illetve R1(felsõ 8 bit) regiszterekben van benne.
;		A program az adatmemória egyes részeit is használja:
;		R7 a 10h, R6 a 11h címre kerül egybõl az inicializálás során
;		30h- DIGIT1	(egyes helyiérték)
;		31h- DIGIT2	(tizes helyiérték)
;		32h- DIGIT3	(százas helyiérték)
;		33h- DIGIT4	(ezres helyiérték)
;		11h- DIGIT5	(tizezres helyiérték) (A program folyamán folyamatosan fölülíródik az eredeti szám
; 		Ahol DIGIT5 a legmagasabb helyiértéket jelöli.
;		40h- MAIN ciklus iterátor lementése
; -----------------------------------------------------------

$NOMOD51 ; a sztenderd 8051 regiszter definíciók nem szükségesek


$INCLUDE (SI_EFM8BB3_Defs.inc) ; regiszter és SFR definíciók

; Ugrótábla létrehozása
	CSEG AT 0
	LJMP Main

myprog SEGMENT CODE			;saját kódszegmens létrehozása
RSEG myprog 				;saját kódszegmens kiválasztása
; ------------------------------------------------------------
; Fõprogram
; ------------------------------------------------------------
; Feladata: a szükséges inicializációs lépések elvégzése és a
;			feladatot megvalósító szubrutin(ok) meghívása
;			Tartalmaz egy LOOP-ot, ami a 10-es osztásokat végzi el.
; ------------------------------------------------------------
Main:
	MOV R0, #10000000b				; alsó input
	MOV R1, #10000000b				; felsõ input
	MOV R2, #0
	MOV R3, #0
	MOV R4, #0
	MOV R5, #0
	MOV R6, #0
	MOV R7, #0
	MOV A, R1
	MOV 10h, A
	MOV A, R0
	MOV 11h, A
	MOV R1, #0				; Itt biztosítjuk, hogy alapértelmezetten minden pozitív szám
	MOV R0, #30h			; Itt fognak majd elhelyezkedni a digitek
	SIGNMASK EQU 10000000b
	CALL SIGN				; Elõjel megállapítása
	Loop:
		CALL DIV_10			; A 10-es osztást megvalósító rutin
		MOV 11h, R6
		MOV 10h, R7			; A hányados értékét elmenti a program
		MOV A, #0
		ADD A, R3
		MOV @R0, A			; R3-ban tárolt maradékot az R0 regiszter által kijelölt címre helyezzük el
		INC R0				; megnöveljük R0-ban tárolt címnek az értékét
		MOV A, #0
		MOV R3, A
		MOV R4, A
		MOV R5, A
		MOV R6, A
		MOV R7, A			; Minden regisztert lenullázunk, hogy ne okozzon zavart a késõbbiekben
		INC R2				; Iterátor növelése
		MOV A, R2
		CJNE A, #4, Loop	; Ha megtörtént már 4 osztás, akkor nem kell tovább osztani
	CALL PackedBCD			; A kimeneti regiszterek elõállítása
	Waiting:
		NOP
		JMP Waiting

; -----------------------------------------------------------
; SIGN szubrutin
; -----------------------------------------------------------
; Funkció: 		Elõjelbit meghatározása,
;				ha pozitív szám: Visszalépünk mainbe, és folytatjuk a programot
;				ha negatív szám: megkezdõdik a pozitívba való átváltás, a NegativeNum címkénél
; Bementek:		-
; Kimenetek:  	R1
; Regisztereket módosítja:
;				A, (10h és 11h)
; -----------------------------------------------------------

SIGN:
	MOV A, 10h					; A legfelsõ 8 bit elsõ bitjét szeretnénk megvizsgálni
	ANL A, #SIGNMASK			; Lemaszkoljuk az A-t
	CJNE A, #0, NegativeNum		; Ha A nem 0 (mert 1 volt az elõjel), akkor átváltjuk pozitívba a számot
	RET
NegativeNum:					; Az átváltás algoritmusa a következõ:
	MOV A, 10h					; Negáljuk a szám bitjeit, és hozzáadunk 1-et
	CPL A						; Ha ez a hozzáadás túlcsordulást eredményez az alsó regiszterben
	MOV 10h, A					; Akkor a felsõ regiszterben is hozzáadjuk az 1-et
	MOV A, 11h
	CPL A
	INC A
	JNZ NoOF
	MOV 11h, A
	MOV A, 10h
	INC A
	MOV 10h, A
NoOF:
	MOV R1, #SIGNMASK			; R1 regiszterbe lementjük az elõjelet (alapértelemzetten 0, csak akkor lépünk ide, ha 1 volt)
	RET

;***********************************************************************************************************************************;

; -----------------------------------------------------------
; DIV_10 szubrutin
; -----------------------------------------------------------
; Funkció: 		A 16 bites számunkat elosztja 10-el. A nem visszaállításos osztás algoritmusát használja fel (részletesebben: dokumentációban)
; Bementek:		10h, 11h
; Kimenetek:  	R7, R6
; Regisztereket módosítja:
;				A, R7, R6, R5, R3, R2,
; -----------------------------------------------------------

DIV_10:
	MOV 40h, R2			; R2 (fõciklus iterátor lementése)
	MOV R2, #8			; R2 az iterátor, õ tárolja hanyadik bitet kell éppen betölteni
	UpperDivision:
		CALL LOAD_Upper		;10h-bõl leszedi a felsõ bitet, és berakja R3-ba
		CALL SUBB_10		;Kivonunk R3 regiszterbõl 10-et
	ResultUpper:
			CALL Dividend_Shift			; Lementjük az 5. bit-et, majd shiftelünk
			CALL Result_Shift_Upper		; Frissítjük az eredmény regisztereinket, az 5. bit negáltával
			DJNZ R2, UpperContinue		; Ha nem értük el a végét, akkor folytatódik az algoritmus
			MOV R2, #8					; Ha R2 == 0, akkor visszatöltjük a 8-at, és megyünk az alsó bitekre
			JMP LowerDivisionStart			; LowerDivision címkénél kezdõdik el az alsó 8 bit kezelése
		UpperContinue:
			MOV A, R4					; Az akkumulátorba betöltjük az R4-et
			JNZ UpperDivision			; Ha R4 = 1, akkor osztás mûvelet kell, mert meg volt benne a szám
			CALL LOAD_Upper
			CALL ADD_10
			JMP ResultUpper
	LowerDivisionStart:						; Fontos a kontextus váltás, így mielõtt elkezdõdik az alsó 8 bittel kapcsolatos számolás
		MOV A, R4							; Megvizsgáljuk, hogy milyen mûveletnek kell következnie
		JNZ Sublower
		JZ LowerContinue
		Sublower:
		CALL LOAD_Lower
		CALL SUBB_10
		JMP Examine
	ResultLower:
			CALL Dividend_Shift
			CALL Result_Shift_Lower
			DJNZ R2, LowerContinue		; Ha ismételten elfogy az iterátorunk, befejezzük az osztásokat
			JMP Ending
		LowerContinue:
			MOV A, R4
			JNZ Sublower
			CALL LOAD_Lower
			CALL ADD_10
			JMP Examine
	Examine:					; Ennek a Labelnek az az oka, hogy le kell kezelni azt az esetet, ha vége a osztásnak, de nem akarjuk a maradékot
		MOV A, R2						; tartalmazó regisztert "bántani", de a a hányadosra ugyanúgy szükségünk van
		DEC A
		JNZ ResultLower
		MOV A, R3
		ANL A, #16
		CJNE A, #16, ZeroPreEnd	; (A == 16)? ha igen, akkor megy tovább, ha nem akkor ugrik
		MOV R4, #0			; Ha equal, akkor az azt jelenti, hogy nem volt meg benne, legyen R4 értéke 0
		JMP PreEnd
	ZeroPreEnd:
		MOV R4, #1		; Ha 1: meg volt benne
	PreEnd:
		CALL Result_Shift_Lower
	Ending:
		MOV A, R4
		JNZ CorrectionEnd		; Lényeg: Ha az utolsó maradékunk nem volt meg (tehát 0 lett a legalsó hányados bit
		CALL ADD_10				; akkor azt vissza kell állítani egy +10-el (itt már semmilyen shiftelésre nincsen szükség)
		CorrectionEnd: ; Ennél a pontnál R7, R6 tartalmazza a hányadost, R3 meg a maradékot
		CLR A
		ADD A, 40h
		MOV R2, A
		RET

; -----------------------------------------------------------
; LOAD_Upper szubrutin
; -----------------------------------------------------------
; Funkció: 		Betölti az input regiszter adott ciklusbeli MSB-jét, az osztandót tartalmazó regiszter (R3) legalsó bitjére.
;				Ha R2 tartalmazza, hogy hanyadik osztásnál vagyunk, akkor (R2-1)-et kell shiftelni az input regiszter tartalmán, hogy a
;				kívánt bitet, az akkumulátor elejére rakjuk
;				Lekezelendõ eset az, ha utolsó ciklusunk kezdõdik, azaz R2=1. Ilyenkor nem kell shiftelni, hiszen már alapjáraton az utolsó bitnél járunk.
; Bementek:		10h - Input felsõ 8 bitje
;				R2 - Ciklus iterátor
; Kimenetek:  	R3 - mindenkori osztandót tartalmazó regiszter
; Regisztereket módosítja:
;				A, R5, R3
; -----------------------------------------------------------

LOAD_Upper:
	MOV A, R2				; lementjük R2 értékét (DIV10 iterátor), azt tartalmazza, hogy hanyadik osztásnál vagyunk
	MOV R5, A
	MOV A, 10h				; 10h a felsõ 8 bit, betöltjük a tartalmát az akkumulátorba
	DEC R2					; Csökkentjük az iterátort.
	CJNE R2, #0, RShift1	; Ha R2 1 volt, akkor DEC után 0 lenne. Tehát 0-t kell shiftelni rajta (nem kell shiftelni). Ha nem így van, akkor shift!
	JMP Last1
	RShift1:				; Loop
		RR A				; Jobbra shifteljük A tartalmát
		DJNZ R2, RShift1	; Amíg R2 nem lesz 0, addig megy a ciklus (R2-1)-et kell shiftelni, hogy elsõ helyre kerüljön a bit
	Last1:
		ANL A, #1			; Lemaszkoljuk A tartalmát, hogy csak a legalsó bit legyen meg
		ADD A, R3			; R3 itt már a shiftelt változat (elsõ lefutásnál nem kellett még shiftelni, második lefutásnál ez a shiftelés után hívódik meg
		MOV R3, A			; Az eredményt visszatöltjük R3-ba
		MOV A, R5			; R2 visszatöltése R5-bõl
		MOV R2, A
		RET

; -----------------------------------------------------------
; LOAD_Lower szubrutin
; -----------------------------------------------------------
; Funkció: 		Betölti az input regiszter adott ciklusbeli MSB-jét, az osztandót tartalmazó regiszter (R3) legalsó bitjére.
;				Ha R2 tartalmazza, hogy hanyadik osztásnál vagyunk, akkor (R2-1)-et kell shiftelni az input regiszter tartalmán, hogy a
;				kívánt bitet, az akkumulátor elejére rakjuk
;				Lekezelendõ eset az, ha utolsó ciklusunk kezdõdik, azaz R2=1. Ilyenkor nem kell shiftelni, hiszen már alapjáraton az utolsó bitnél járunk.
; Bementek:		11h - Input alsó 8 bitje
;				R2 - Ciklus iterátor
; Kimenetek:  	R3 - mindenkori osztandót tartalmazó regiszter
; Regisztereket módosítja:
;				A, R5, R3
; -----------------------------------------------------------

LOAD_Lower:
	MOV A, R2				; Lementjük R2 értékét (DIV10 iterátor), azt tartalmazza, hogy hanyadik osztásnál vagyunk
	MOV R5, A
	MOV A, 11h				; Az akkumulátorba helyezzük az alsó 8 bitet
	DEC R2					; Csökkentjük az iterátor értékét
	CJNE R2, #0, RShift2	; Ha R2 1 volt, akkor DEC után 0 lenne. Tehát 0-t kell shiftelni rajta (nem kell shiftelni). Ha nem így van, akkor shift!
	JMP Last2				; Kihagyjuk fenti esetben a shiftelést
	RShift2:				; Loop
		RR A				; Akkumulátor
		DJNZ R2, RShift2	; Amíg R2 nem lesz 0, addig megy a ciklus (R2-1)-et kell shiftelni, hogy elsõ helyre kerüljön a bit
	Last2:
		ANL A, #1			; Lemaszkoljuk A tartalmát, hogy csak a legalsó bit legyen meg
		ADD A, R3			; R3 itt már a shiftelt változat (elsõ lefutásnál nem kellett még shiftelni, második lefutásnál ez a shiftelés után hívódik meg
		MOV R3, A			; Az eredményt visszatöltjük R3-ba
		MOV A, R5			; R2 visszatöltése R5-bõl
		MOV R2, A
		RET

; -----------------------------------------------------------
; SUBB_10: szubrutin
; -----------------------------------------------------------
; Funkció: 		Kivon R3-ból 10-et
; Bementek:
; Kimenetek:  	R3 - mindenkori osztandót tartalmazó regiszter
; Regisztereket módosítja:
;				A R3
; -----------------------------------------------------------

SUBB_10:
	MOV A, R3		; Betöltjük R3 értéket az akkumulátorba
	SUBB A, #10		; Kivonunk belõle 10-et
	ANL A, #00011111b
	MOV R3, A		; Eltároljuk a kivonás eredményét R3-ban
	RET

; -----------------------------------------------------------
; ADD_10: szubrutin
; -----------------------------------------------------------
; Funkció: 		Hozzáad R3-hoz 10-et
; Bementek:
; Kimenetek:  	R3 - mindenkori osztandót tartalmazó regiszter
; Regisztereket módosítja:
;				A R3
; -----------------------------------------------------------

ADD_10:
	MOV A, R3		; Betöltjük R3 értéket az akkumulátorba
	ADD A, #10		; Hozzáadunk 10-et
	ANL A, #00011111b
	MOV R3, A		; Eltároljuk az összeadás eredményét R3-ban
	RET

; -----------------------------------------------------------
; Dividend_Shift szubrutin
; -----------------------------------------------------------
; Funkció: 		Az R3 regiszter (mindenkori osztandó) 5. bitjének a komplementerének a lementése R4 regiszterbe és R3 shiftelése
;				, hogy a késõbbiekben a betöltés nagyon egyszerû legyen.
; Bementek:		R3 - mindenkori osztandót tartalmazó regiszter
; Kimenetek:  	R3 - mindenkori osztandót tartalmazó regiszter
;				R4 - "Carry negált"
; Regisztereket módosítja:
;				A, R3, R4
; -----------------------------------------------------------

Dividend_Shift:

	MOV A, R3			; R3 tartalmát betesszük az akkumulátorba. Emlékeztetõ:R3 tartalmazza egy osztás eredményét
	ANL A, #16 			; 5. bitet lemaszkoljuk
	CJNE A, #16, Zero	; (A == 16)? ha igen, akkor megy tovább, ha nem akkor ugrik
	MOV R4, #0			; Ha equal, akkor az azt jelenti, hogy nem volt meg benne, legyen R4 értéke 0 (legközelebb ADDmûvelet kell)
	JMP ShiftDividend
	Zero:
		MOV R4, #1		; Ha 1: meg volt benne, legközelebb SUBB kell
	ShiftDividend:
		MOV A, R3			; R3 betöltése A-ba
		RL A				; A shiftelése, helyet szorítani majd az alsó bit betöltésének
		ANL A, #00011110b	; A maszkolása (nem kell a legalsó bit, se a felsõ 3)
		MOV R3, A
		RET

; -----------------------------------------------------------
; Result_Shift_Upper szubrutin
; -----------------------------------------------------------
; Funkció: 		A felsõ 8 bitet tartalmazó kimeneti regiszter tartalmának módosítása. Betöltjük az akkumulátorba az R4 regiszter tartalmát
;				R4 == 0, ha az osztás eredménye az, hogy nem volt meg benne a szám, és ezért 0-at kell adott bitbe tölteni
;				R4 == 0, ha az osztás eredménye az, hogy meg volt benne a szám, és ezért 1-et kell adott bitbe tölteni
; Bementek:		R2 - iterátor
;				R4 - "Carry negált"
; Kimenetek:
;				R7 - Hányados felsõ 8 bitjét tartalmazó regiszter
; Regisztereket módosítja:
;				A, R5, R7
; -----------------------------------------------------------

Result_Shift_Upper: 			; R4 megmondja hogy mit kell tölteni, R2 hogy hova
	MOV A, R2					; R2 lementése R5-be
	MOV R5, A
	MOV A, R4					; R4 betöltése A-ba
	DJNZ R2, LoopResultUpper 	; Ha utolsó ciklusnál vagyunk, nem kell shiftelni
	JMP ShiftResultUpper
	LoopResultUpper:
		RL A					; Balra shiftelünk
		DJNZ R2, LoopResultUpper
	ShiftResultUpper:
		ADD A, R7				; R7 eddigi tartalmát hozzáadjuk a shiftelt akkumulátorhoz
		MOV R7, A				; Visszatöltjük R7-et
		MOV A, R5				; Visszaállítjuk R2-t
		MOV R2, A
		RET

; -----------------------------------------------------------
; Result_Shift_Lower szubrutin
; -----------------------------------------------------------
; Funkció: 		Az alsó 8 bitet tartalmazó kimeneti regiszter tartalmának módosítása. Betöltjük az akkumulátorba az R4 regiszter tartalmát
;				R4 == 0, ha az osztás eredménye az, hogy nem volt meg benne a szám, és ezért 0-at kell adott bitbe tölteni
;				R4 == 0, ha az osztás eredménye az, hogy meg volt benne a szám, és ezért 1-et kell adott bitbe tölteni
; Bementek:		R2 - iterátor
;				R4 - "Carry negált"
; Kimenetek:
;				R6 - Hányados alsó 8 bitjét tartalmazó regiszter
; Regisztereket módosítja:
;				A, R5, R6
; -----------------------------------------------------------

Result_Shift_Lower: ; R4 megmondja hogy mit kell tölteni, R2 hogy hova
	MOV A, R2				; R2 lementése R5-be
	MOV R5, A
	MOV A, R4				; R4 betöltése A-ba
	DJNZ R2, LoopResultLower	; Ha utolsó ciklusnál vagyunk, nem kell shiftelni
	JMP ShiftResultLower
	LoopResultLower:
		RL A					; Balra shiftelünk
		DJNZ R2, LoopResultLower
	ShiftResultLower:
		ADD A, R6				; R7 eddigi tartalmát hozzáadjuk a shiftelt akkumulátorhoz
		MOV R6, A				; Visszatöltjük R7-et
		MOV A, R5				; Visszaállítjuk R2-t
		MOV R2, A
		RET

; -----------------------------------------------------------
; PackedBCD szubrutin
; -----------------------------------------------------------
; Funkció: 		A kimeneti regiszterek beállítása a feladatkiírásnak megfelelõen
;				PackedBCD: Egy olyan regiszter, aminek az alsó és felsõ 4 bitje 1-1 digitet reprezentál
; Bementek:		11h, 30h, 31h, 32h, 33h
;				R1 - Elõjelet tartalmazó regiszter
; Kimenetek:
;				R7 - Elõjel + 5. digit
;				R6 - 4. és 3. digit
;				R5 - 2. és 1. digit
; Regisztereket módosítja:
;				A, R5, R6, R7
; -----------------------------------------------------------


PackedBCD: 			; Legnagyobb helyiérték 11h-n, A többi (csökkenõ sorrendben)): 33h, 32h, 31h, 30h
	CLR A			; Kimeneti regiszterek legyenek: R7 R6 R5
	MOV A, R1		; elõjel
	ADD A, 11h
	MOV R7, A		; Elõjel+ 5. digit kész
	CLR A
	ADD A, 33h
	SWAP A
	ADD A, 32h
	MOV R6, A		; 4. 3. digit kész
	CLR A
	ADD A, 31h
	SWAP A
	ADD A, 30h
	MOV R5, A		; 1. 2. digit kész
	CLR A
	RET


END
