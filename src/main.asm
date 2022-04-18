; -----------------------------------------------------------
; Mikrokontroller alap� rendszerek h�zi feladat
; K�sz�tette: Koren Zolt�n
; Neptun code: HOTQM1
; Feladat le�r�sa:
;		Regiszterekben tal�lhat� 16 bites el�jeles eg�sz �talak�t�sa 5 db BCD k�d� sz�mm� + el�jell�.
;		Az eredm�nyt 3 regiszterben kapjuk vissza: az els�ben a legfels� bit az el�jel, az alatta l�v�
;		3 bit 0, ez alatt a legmagasabb helyi�rt�k� digit. A m�sodik regiszterben a k�vetkez� k�t digit,
;		a harmadikban a legkisebb helyi�rt�k� k�t digit. Bemenet: az �talak�tand� sz�m 2 regiszterben,
;		kimenet az �talak�tott sz�m 3 regiszterben.
;
;-------------------------------------------------------------
;Kieg�sz�t�s:
;		A 16 bites bin�ris sz�m az R0(als� 8 bit), illetve R1(fels� 8 bit) regiszterekben van benne.
;		A program az adatmem�ria egyes r�szeit is haszn�lja:
;		R7 a 10h, R6 a 11h c�mre ker�l egyb�l az inicializ�l�s sor�n
;		30h- DIGIT1	(egyes helyi�rt�k)
;		31h- DIGIT2	(tizes helyi�rt�k)
;		32h- DIGIT3	(sz�zas helyi�rt�k)
;		33h- DIGIT4	(ezres helyi�rt�k)
;		11h- DIGIT5	(tizezres helyi�rt�k) (A program folyam�n folyamatosan f�l�l�r�dik az eredeti sz�m
; 		Ahol DIGIT5 a legmagasabb helyi�rt�ket jel�li.
;		40h- MAIN ciklus iter�tor lement�se
; -----------------------------------------------------------

$NOMOD51 ; a sztenderd 8051 regiszter defin�ci�k nem sz�ks�gesek


$INCLUDE (SI_EFM8BB3_Defs.inc) ; regiszter �s SFR defin�ci�k

; Ugr�t�bla l�trehoz�sa
	CSEG AT 0
	LJMP Main

myprog SEGMENT CODE			;saj�t k�dszegmens l�trehoz�sa
RSEG myprog 				;saj�t k�dszegmens kiv�laszt�sa
; ------------------------------------------------------------
; F�program
; ------------------------------------------------------------
; Feladata: a sz�ks�ges inicializ�ci�s l�p�sek elv�gz�se �s a
;			feladatot megval�s�t� szubrutin(ok) megh�v�sa
;			Tartalmaz egy LOOP-ot, ami a 10-es oszt�sokat v�gzi el.
; ------------------------------------------------------------
Main:
	MOV R0, #10000000b				; als� input
	MOV R1, #10000000b				; fels� input
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
	MOV R1, #0				; Itt biztos�tjuk, hogy alap�rtelmezetten minden pozit�v sz�m
	MOV R0, #30h			; Itt fognak majd elhelyezkedni a digitek
	SIGNMASK EQU 10000000b
	CALL SIGN				; El�jel meg�llap�t�sa
	Loop:
		CALL DIV_10			; A 10-es oszt�st megval�s�t� rutin
		MOV 11h, R6
		MOV 10h, R7			; A h�nyados �rt�k�t elmenti a program
		MOV A, #0
		ADD A, R3
		MOV @R0, A			; R3-ban t�rolt marad�kot az R0 regiszter �ltal kijel�lt c�mre helyezz�k el
		INC R0				; megn�velj�k R0-ban t�rolt c�mnek az �rt�k�t
		MOV A, #0
		MOV R3, A
		MOV R4, A
		MOV R5, A
		MOV R6, A
		MOV R7, A			; Minden regisztert lenull�zunk, hogy ne okozzon zavart a k�s�bbiekben
		INC R2				; Iter�tor n�vel�se
		MOV A, R2
		CJNE A, #4, Loop	; Ha megt�rt�nt m�r 4 oszt�s, akkor nem kell tov�bb osztani
	CALL PackedBCD			; A kimeneti regiszterek el��ll�t�sa
	Waiting:
		NOP
		JMP Waiting

; -----------------------------------------------------------
; SIGN szubrutin
; -----------------------------------------------------------
; Funkci�: 		El�jelbit meghat�roz�sa,
;				ha pozit�v sz�m: Visszal�p�nk mainbe, �s folytatjuk a programot
;				ha negat�v sz�m: megkezd�dik a pozit�vba val� �tv�lt�s, a NegativeNum c�mk�n�l
; Bementek:		-
; Kimenetek:  	R1
; Regisztereket m�dos�tja:
;				A, (10h �s 11h)
; -----------------------------------------------------------

SIGN:
	MOV A, 10h					; A legfels� 8 bit els� bitj�t szeretn�nk megvizsg�lni
	ANL A, #SIGNMASK			; Lemaszkoljuk az A-t
	CJNE A, #0, NegativeNum		; Ha A nem 0 (mert 1 volt az el�jel), akkor �tv�ltjuk pozit�vba a sz�mot
	RET
NegativeNum:					; Az �tv�lt�s algoritmusa a k�vetkez�:
	MOV A, 10h					; Neg�ljuk a sz�m bitjeit, �s hozz�adunk 1-et
	CPL A						; Ha ez a hozz�ad�s t�lcsordul�st eredm�nyez az als� regiszterben
	MOV 10h, A					; Akkor a fels� regiszterben is hozz�adjuk az 1-et
	MOV A, 11h
	CPL A
	INC A
	JNZ NoOF
	MOV 11h, A
	MOV A, 10h
	INC A
	MOV 10h, A
NoOF:
	MOV R1, #SIGNMASK			; R1 regiszterbe lementj�k az el�jelet (alap�rtelemzetten 0, csak akkor l�p�nk ide, ha 1 volt)
	RET

;***********************************************************************************************************************************;

; -----------------------------------------------------------
; DIV_10 szubrutin
; -----------------------------------------------------------
; Funkci�: 		A 16 bites sz�munkat elosztja 10-el. A nem vissza�ll�t�sos oszt�s algoritmus�t haszn�lja fel (r�szletesebben: dokument�ci�ban)
; Bementek:		10h, 11h
; Kimenetek:  	R7, R6
; Regisztereket m�dos�tja:
;				A, R7, R6, R5, R3, R2,
; -----------------------------------------------------------

DIV_10:
	MOV 40h, R2			; R2 (f�ciklus iter�tor lement�se)
	MOV R2, #8			; R2 az iter�tor, � t�rolja hanyadik bitet kell �ppen bet�lteni
	UpperDivision:
		CALL LOAD_Upper		;10h-b�l leszedi a fels� bitet, �s berakja R3-ba
		CALL SUBB_10		;Kivonunk R3 regiszterb�l 10-et
	ResultUpper:
			CALL Dividend_Shift			; Lementj�k az 5. bit-et, majd shiftel�nk
			CALL Result_Shift_Upper		; Friss�tj�k az eredm�ny regisztereinket, az 5. bit neg�lt�val
			DJNZ R2, UpperContinue		; Ha nem �rt�k el a v�g�t, akkor folytat�dik az algoritmus
			MOV R2, #8					; Ha R2 == 0, akkor visszat�ltj�k a 8-at, �s megy�nk az als� bitekre
			JMP LowerDivisionStart			; LowerDivision c�mk�n�l kezd�dik el az als� 8 bit kezel�se
		UpperContinue:
			MOV A, R4					; Az akkumul�torba bet�ltj�k az R4-et
			JNZ UpperDivision			; Ha R4 = 1, akkor oszt�s m�velet kell, mert meg volt benne a sz�m
			CALL LOAD_Upper
			CALL ADD_10
			JMP ResultUpper
	LowerDivisionStart:						; Fontos a kontextus v�lt�s, �gy miel�tt elkezd�dik az als� 8 bittel kapcsolatos sz�mol�s
		MOV A, R4							; Megvizsg�ljuk, hogy milyen m�veletnek kell k�vetkeznie
		JNZ Sublower
		JZ LowerContinue
		Sublower:
		CALL LOAD_Lower
		CALL SUBB_10
		JMP Examine
	ResultLower:
			CALL Dividend_Shift
			CALL Result_Shift_Lower
			DJNZ R2, LowerContinue		; Ha ism�telten elfogy az iter�torunk, befejezz�k az oszt�sokat
			JMP Ending
		LowerContinue:
			MOV A, R4
			JNZ Sublower
			CALL LOAD_Lower
			CALL ADD_10
			JMP Examine
	Examine:					; Ennek a Labelnek az az oka, hogy le kell kezelni azt az esetet, ha v�ge a oszt�snak, de nem akarjuk a marad�kot
		MOV A, R2						; tartalmaz� regisztert "b�ntani", de a a h�nyadosra ugyan�gy sz�ks�g�nk van
		DEC A
		JNZ ResultLower
		MOV A, R3
		ANL A, #16
		CJNE A, #16, ZeroPreEnd	; (A == 16)? ha igen, akkor megy tov�bb, ha nem akkor ugrik
		MOV R4, #0			; Ha equal, akkor az azt jelenti, hogy nem volt meg benne, legyen R4 �rt�ke 0
		JMP PreEnd
	ZeroPreEnd:
		MOV R4, #1		; Ha 1: meg volt benne
	PreEnd:
		CALL Result_Shift_Lower
	Ending:
		MOV A, R4
		JNZ CorrectionEnd		; L�nyeg: Ha az utols� marad�kunk nem volt meg (teh�t 0 lett a legals� h�nyados bit
		CALL ADD_10				; akkor azt vissza kell �ll�tani egy +10-el (itt m�r semmilyen shiftel�sre nincsen sz�ks�g)
		CorrectionEnd: ; Enn�l a pontn�l R7, R6 tartalmazza a h�nyadost, R3 meg a marad�kot
		CLR A
		ADD A, 40h
		MOV R2, A
		RET

; -----------------------------------------------------------
; LOAD_Upper szubrutin
; -----------------------------------------------------------
; Funkci�: 		Bet�lti az input regiszter adott ciklusbeli MSB-j�t, az osztand�t tartalmaz� regiszter (R3) legals� bitj�re.
;				Ha R2 tartalmazza, hogy hanyadik oszt�sn�l vagyunk, akkor (R2-1)-et kell shiftelni az input regiszter tartalm�n, hogy a
;				k�v�nt bitet, az akkumul�tor elej�re rakjuk
;				Lekezelend� eset az, ha utols� ciklusunk kezd�dik, azaz R2=1. Ilyenkor nem kell shiftelni, hiszen m�r alapj�raton az utols� bitn�l j�runk.
; Bementek:		10h - Input fels� 8 bitje
;				R2 - Ciklus iter�tor
; Kimenetek:  	R3 - mindenkori osztand�t tartalmaz� regiszter
; Regisztereket m�dos�tja:
;				A, R5, R3
; -----------------------------------------------------------

LOAD_Upper:
	MOV A, R2				; lementj�k R2 �rt�k�t (DIV10 iter�tor), azt tartalmazza, hogy hanyadik oszt�sn�l vagyunk
	MOV R5, A
	MOV A, 10h				; 10h a fels� 8 bit, bet�ltj�k a tartalm�t az akkumul�torba
	DEC R2					; Cs�kkentj�k az iter�tort.
	CJNE R2, #0, RShift1	; Ha R2 1 volt, akkor DEC ut�n 0 lenne. Teh�t 0-t kell shiftelni rajta (nem kell shiftelni). Ha nem �gy van, akkor shift!
	JMP Last1
	RShift1:				; Loop
		RR A				; Jobbra shiftelj�k A tartalm�t
		DJNZ R2, RShift1	; Am�g R2 nem lesz 0, addig megy a ciklus (R2-1)-et kell shiftelni, hogy els� helyre ker�lj�n a bit
	Last1:
		ANL A, #1			; Lemaszkoljuk A tartalm�t, hogy csak a legals� bit legyen meg
		ADD A, R3			; R3 itt m�r a shiftelt v�ltozat (els� lefut�sn�l nem kellett m�g shiftelni, m�sodik lefut�sn�l ez a shiftel�s ut�n h�v�dik meg
		MOV R3, A			; Az eredm�nyt visszat�ltj�k R3-ba
		MOV A, R5			; R2 visszat�lt�se R5-b�l
		MOV R2, A
		RET

; -----------------------------------------------------------
; LOAD_Lower szubrutin
; -----------------------------------------------------------
; Funkci�: 		Bet�lti az input regiszter adott ciklusbeli MSB-j�t, az osztand�t tartalmaz� regiszter (R3) legals� bitj�re.
;				Ha R2 tartalmazza, hogy hanyadik oszt�sn�l vagyunk, akkor (R2-1)-et kell shiftelni az input regiszter tartalm�n, hogy a
;				k�v�nt bitet, az akkumul�tor elej�re rakjuk
;				Lekezelend� eset az, ha utols� ciklusunk kezd�dik, azaz R2=1. Ilyenkor nem kell shiftelni, hiszen m�r alapj�raton az utols� bitn�l j�runk.
; Bementek:		11h - Input als� 8 bitje
;				R2 - Ciklus iter�tor
; Kimenetek:  	R3 - mindenkori osztand�t tartalmaz� regiszter
; Regisztereket m�dos�tja:
;				A, R5, R3
; -----------------------------------------------------------

LOAD_Lower:
	MOV A, R2				; Lementj�k R2 �rt�k�t (DIV10 iter�tor), azt tartalmazza, hogy hanyadik oszt�sn�l vagyunk
	MOV R5, A
	MOV A, 11h				; Az akkumul�torba helyezz�k az als� 8 bitet
	DEC R2					; Cs�kkentj�k az iter�tor �rt�k�t
	CJNE R2, #0, RShift2	; Ha R2 1 volt, akkor DEC ut�n 0 lenne. Teh�t 0-t kell shiftelni rajta (nem kell shiftelni). Ha nem �gy van, akkor shift!
	JMP Last2				; Kihagyjuk fenti esetben a shiftel�st
	RShift2:				; Loop
		RR A				; Akkumul�tor
		DJNZ R2, RShift2	; Am�g R2 nem lesz 0, addig megy a ciklus (R2-1)-et kell shiftelni, hogy els� helyre ker�lj�n a bit
	Last2:
		ANL A, #1			; Lemaszkoljuk A tartalm�t, hogy csak a legals� bit legyen meg
		ADD A, R3			; R3 itt m�r a shiftelt v�ltozat (els� lefut�sn�l nem kellett m�g shiftelni, m�sodik lefut�sn�l ez a shiftel�s ut�n h�v�dik meg
		MOV R3, A			; Az eredm�nyt visszat�ltj�k R3-ba
		MOV A, R5			; R2 visszat�lt�se R5-b�l
		MOV R2, A
		RET

; -----------------------------------------------------------
; SUBB_10: szubrutin
; -----------------------------------------------------------
; Funkci�: 		Kivon R3-b�l 10-et
; Bementek:
; Kimenetek:  	R3 - mindenkori osztand�t tartalmaz� regiszter
; Regisztereket m�dos�tja:
;				A R3
; -----------------------------------------------------------

SUBB_10:
	MOV A, R3		; Bet�ltj�k R3 �rt�ket az akkumul�torba
	SUBB A, #10		; Kivonunk bel�le 10-et
	ANL A, #00011111b
	MOV R3, A		; Elt�roljuk a kivon�s eredm�ny�t R3-ban
	RET

; -----------------------------------------------------------
; ADD_10: szubrutin
; -----------------------------------------------------------
; Funkci�: 		Hozz�ad R3-hoz 10-et
; Bementek:
; Kimenetek:  	R3 - mindenkori osztand�t tartalmaz� regiszter
; Regisztereket m�dos�tja:
;				A R3
; -----------------------------------------------------------

ADD_10:
	MOV A, R3		; Bet�ltj�k R3 �rt�ket az akkumul�torba
	ADD A, #10		; Hozz�adunk 10-et
	ANL A, #00011111b
	MOV R3, A		; Elt�roljuk az �sszead�s eredm�ny�t R3-ban
	RET

; -----------------------------------------------------------
; Dividend_Shift szubrutin
; -----------------------------------------------------------
; Funkci�: 		Az R3 regiszter (mindenkori osztand�) 5. bitj�nek a komplementer�nek a lement�se R4 regiszterbe �s R3 shiftel�se
;				, hogy a k�s�bbiekben a bet�lt�s nagyon egyszer� legyen.
; Bementek:		R3 - mindenkori osztand�t tartalmaz� regiszter
; Kimenetek:  	R3 - mindenkori osztand�t tartalmaz� regiszter
;				R4 - "Carry neg�lt"
; Regisztereket m�dos�tja:
;				A, R3, R4
; -----------------------------------------------------------

Dividend_Shift:

	MOV A, R3			; R3 tartalm�t betessz�k az akkumul�torba. Eml�keztet�:R3 tartalmazza egy oszt�s eredm�ny�t
	ANL A, #16 			; 5. bitet lemaszkoljuk
	CJNE A, #16, Zero	; (A == 16)? ha igen, akkor megy tov�bb, ha nem akkor ugrik
	MOV R4, #0			; Ha equal, akkor az azt jelenti, hogy nem volt meg benne, legyen R4 �rt�ke 0 (legk�zelebb ADDm�velet kell)
	JMP ShiftDividend
	Zero:
		MOV R4, #1		; Ha 1: meg volt benne, legk�zelebb SUBB kell
	ShiftDividend:
		MOV A, R3			; R3 bet�lt�se A-ba
		RL A				; A shiftel�se, helyet szor�tani majd az als� bit bet�lt�s�nek
		ANL A, #00011110b	; A maszkol�sa (nem kell a legals� bit, se a fels� 3)
		MOV R3, A
		RET

; -----------------------------------------------------------
; Result_Shift_Upper szubrutin
; -----------------------------------------------------------
; Funkci�: 		A fels� 8 bitet tartalmaz� kimeneti regiszter tartalm�nak m�dos�t�sa. Bet�ltj�k az akkumul�torba az R4 regiszter tartalm�t
;				R4 == 0, ha az oszt�s eredm�nye az, hogy nem volt meg benne a sz�m, �s ez�rt 0-at kell adott bitbe t�lteni
;				R4 == 0, ha az oszt�s eredm�nye az, hogy meg volt benne a sz�m, �s ez�rt 1-et kell adott bitbe t�lteni
; Bementek:		R2 - iter�tor
;				R4 - "Carry neg�lt"
; Kimenetek:
;				R7 - H�nyados fels� 8 bitj�t tartalmaz� regiszter
; Regisztereket m�dos�tja:
;				A, R5, R7
; -----------------------------------------------------------

Result_Shift_Upper: 			; R4 megmondja hogy mit kell t�lteni, R2 hogy hova
	MOV A, R2					; R2 lement�se R5-be
	MOV R5, A
	MOV A, R4					; R4 bet�lt�se A-ba
	DJNZ R2, LoopResultUpper 	; Ha utols� ciklusn�l vagyunk, nem kell shiftelni
	JMP ShiftResultUpper
	LoopResultUpper:
		RL A					; Balra shiftel�nk
		DJNZ R2, LoopResultUpper
	ShiftResultUpper:
		ADD A, R7				; R7 eddigi tartalm�t hozz�adjuk a shiftelt akkumul�torhoz
		MOV R7, A				; Visszat�ltj�k R7-et
		MOV A, R5				; Vissza�ll�tjuk R2-t
		MOV R2, A
		RET

; -----------------------------------------------------------
; Result_Shift_Lower szubrutin
; -----------------------------------------------------------
; Funkci�: 		Az als� 8 bitet tartalmaz� kimeneti regiszter tartalm�nak m�dos�t�sa. Bet�ltj�k az akkumul�torba az R4 regiszter tartalm�t
;				R4 == 0, ha az oszt�s eredm�nye az, hogy nem volt meg benne a sz�m, �s ez�rt 0-at kell adott bitbe t�lteni
;				R4 == 0, ha az oszt�s eredm�nye az, hogy meg volt benne a sz�m, �s ez�rt 1-et kell adott bitbe t�lteni
; Bementek:		R2 - iter�tor
;				R4 - "Carry neg�lt"
; Kimenetek:
;				R6 - H�nyados als� 8 bitj�t tartalmaz� regiszter
; Regisztereket m�dos�tja:
;				A, R5, R6
; -----------------------------------------------------------

Result_Shift_Lower: ; R4 megmondja hogy mit kell t�lteni, R2 hogy hova
	MOV A, R2				; R2 lement�se R5-be
	MOV R5, A
	MOV A, R4				; R4 bet�lt�se A-ba
	DJNZ R2, LoopResultLower	; Ha utols� ciklusn�l vagyunk, nem kell shiftelni
	JMP ShiftResultLower
	LoopResultLower:
		RL A					; Balra shiftel�nk
		DJNZ R2, LoopResultLower
	ShiftResultLower:
		ADD A, R6				; R7 eddigi tartalm�t hozz�adjuk a shiftelt akkumul�torhoz
		MOV R6, A				; Visszat�ltj�k R7-et
		MOV A, R5				; Vissza�ll�tjuk R2-t
		MOV R2, A
		RET

; -----------------------------------------------------------
; PackedBCD szubrutin
; -----------------------------------------------------------
; Funkci�: 		A kimeneti regiszterek be�ll�t�sa a feladatki�r�snak megfelel�en
;				PackedBCD: Egy olyan regiszter, aminek az als� �s fels� 4 bitje 1-1 digitet reprezent�l
; Bementek:		11h, 30h, 31h, 32h, 33h
;				R1 - El�jelet tartalmaz� regiszter
; Kimenetek:
;				R7 - El�jel + 5. digit
;				R6 - 4. �s 3. digit
;				R5 - 2. �s 1. digit
; Regisztereket m�dos�tja:
;				A, R5, R6, R7
; -----------------------------------------------------------


PackedBCD: 			; Legnagyobb helyi�rt�k 11h-n, A t�bbi (cs�kken� sorrendben)): 33h, 32h, 31h, 30h
	CLR A			; Kimeneti regiszterek legyenek: R7 R6 R5
	MOV A, R1		; el�jel
	ADD A, 11h
	MOV R7, A		; El�jel+ 5. digit k�sz
	CLR A
	ADD A, 33h
	SWAP A
	ADD A, 32h
	MOV R6, A		; 4. 3. digit k�sz
	CLR A
	ADD A, 31h
	SWAP A
	ADD A, 30h
	MOV R5, A		; 1. 2. digit k�sz
	CLR A
	RET


END
