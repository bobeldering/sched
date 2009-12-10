      SUBROUTINE FCOMPARE( KS, KF, MATCH, OKIF, NBAD, PRTMISS )
C
C     Routine for SCHED called by setfcat that compares a setup file KS
C     with a frequency catalog entry to KF see if they are compatible.
C     The purpose is to narrow the range of those that will be
C     used to search for a source of defaults or error checks.
C     MATCH is returned .true. if 
C
C     Require that every channel in the setup file match, in all ways
C     that have already been set in the setup file, an IF in the
C     frequency catalog.  However allow the FREQREF of some, but
C     not all, channels to fall outside the RF ranges.
C
C     Keep track of the best matches.  NBAD is the minimum number
C     of items that did not match for the worst channel.
C
C     SETFCAT will call this routine a second time if a match is
C     not found.  By then NBAD will be set.  On that call, print
C     some details of how the match failed for any with NBAD or
C     NBAD + 1 mismatches.  On those calls, PRTMISS will be .TRUE. 
C
      INCLUDE   'sched.inc'
      INCLUDE   'schset.inc'
      INCLUDE   'schfreq.inc'
C
      INTEGER          KS, KSTA, KF, IFINDX, ICH, IIF, I
      INTEGER          NBAD, CHBAD, IIFBAD, KFBAD
      LOGICAL          MATCH, IFMATCH, OKIF(MCHAN,MFIF)
      LOGICAL          FREQOK(MCHAN), GOTAFR, PRTMISS
      LOGICAL          RFCLOSE
      LOGICAL          FCSTA, FCIFCH, FCFLO1, FCPOL, FCCH1
      LOGICAL          FCFE, FC50, FCVLAIF
      LOGICAL          MFLKA, MFLKB, MFEAB, MFECD, MSYNA, MSYNB
      LOGICAL          MFEF, MVBND, MVBW
      CHARACTER        CHFLAGS*12
C ---------------------------------------------------------------------
C     Initialize MATCH for the return in case a top level item 
C     is no good.
C
      MATCH = .FALSE.
C
C     Check that the first setup file station uses this frequency
C     catalog entry.  Allow VLBA defaults.
C
      FCSTA = .FALSE.
      DO KSTA = 1, MFSTA
         IF( SETSTA(1,KS) .EQ. FSTNAM(KSTA,KF) .OR. 
     1       ( SETSTA(1,KS)(1:4) .EQ. 'VLBA' .AND.
     2         FSTNAM(KSTA,KF)(1:4) .EQ. 'VLBA' ) ) THEN
            FCSTA = .TRUE.
         END IF
      END DO
C
C     Don't waste more time if the station doesn't match
C
      IF( .NOT. FCSTA ) GO TO 1000
C
C     Check frequency match.  Only do debug printout if some 
C     channel matches.  GOTAFR set true if any channel is in
C     the frequency rainge for any IF in the setup.
C
      GOTAFR = .FALSE.
      DO ICH = 1, NCHAN(KS)
         DO IIF = 1, FNIF(KF)
            IF(  FREQREF(ICH,KS) .GE. FRF1(IIF,KF) .AND.
     1           FREQREF(ICH,KS) .LE. FRF2(IIF,KF) ) THEN
               GOTAFR = .TRUE.
            END IF
         END DO
      END DO
C
C     Don't waste more time if no frequency matches
C     Only a few frequency sets should survive past here.
C
      IF( .NOT. GOTAFR ) GO TO 1000
C
C     Initialize OKIF.
C
      DO ICH = 1, NCHAN(KS)
         DO IIF = 1, FNIF(KF)
            OKIF(ICH,IIF) = .FALSE.
         END DO
      END DO
C
C     Print something if debug print is requested.
C
      IF( SDEBUG ) THEN
         SETMSG = ' '
         WRITE( SETMSG, '( A, I4, A, I4 )' )
     1       'FCOMPARE: Got station and frequency match. KS:', KS,
     2       '  KF:', KF
         CALL WLOG( 0, SETMSG )
      END IF
C
C     Check for IFs that match the input channel parameters.
C
      KFBAD = 0
      DO ICH = 1, NCHAN(KS)         
         CHBAD = 99
         DO IIF = 1, FNIF(KF)
C
C           Require any specified IFCHAN match.
C
            FCIFCH = IFCHAN(ICH,KS) .EQ. ' ' .OR.
     1               IFCHAN(ICH,KS) .EQ. FIFNAM(IIF,KF) .OR.
     2               IFCHAN(ICH,KS) .EQ. FALTIF(IIF,KF)
C
C           Require any specified FIRSTLO match
C
            FCFLO1 = FIRSTLO(ICH,KS) .EQ. NOTSET .OR. 
     1               FIRSTLO(ICH,KS) .EQ. FLO1(IIF,KF)
C
C           RF - require be in same general part of RF.  Will
C           check actual RF later.  This is completely require.
C           The other is a precise, but optional (for a subset
C           of channels only) check
C
            RFCLOSE = FREQREF(ICH,KS) .GE. 0.8D0 * FRF1(IIF,KF) .AND.
     1               FREQREF(ICH,KS) .LE. 1.2D0 * FRF2(IIF,KF)
C
C           Require any specified polarization match
C
            FCPOL = POL(ICH,KS) .EQ. ' ' .OR.
     1              POL(ICH,KS)(1:1) .EQ. FPOL(IIF,KF)(1:1)
C
C           For 2 cm, be sure filter will be right.  Depends on
C           frequency of channel 1.  This will work for other bands 
C           too if that should become an issue.
C
            FCCH1 = ( FCH1RF1(IIF,KF) .EQ. 0.D0 .OR.
     1                FCH1RF1(IIF,KF) .LT. FREQREF(1,KS) ) .AND.
     2              ( FCH1RF2(IIF,KF) .EQ. 0.D0 .OR.
     3                FCH1RF2(IIF,KF) .GT. FREQREF(1,KS) )
C
C           For the VLA phased array, try to limit choice of IF.
C           Allow for possible different phasing modes using the
C           same setup (ok for RR only, for example - could use
C           VR or VA).  Actually mixing modes would flagged 
C           elsewhere (true?).  Do this test for any VLA "station" since
C           mixed phasing and non-phasing modes are allowed.
C           All of this will be obsolete soon so I'm not going to
C           worry about it (Dec. 2009)
C
            FCVLAIF = .TRUE.
            IF( SETSTA(1,KS)(1:3) .EQ. 'VLA' ) THEN
               IF( VLAVA(KS) .AND. ( FIFNAM(IIF,KF) .EQ. 'B'
     1           .OR. FIFNAM(IIF,KF) .EQ. 'C' ) ) FCVLAIF = .FALSE.
               IF( VLAVB(KS) .AND. ( FIFNAM(IIF,KF) .EQ. 'A'
     1           .OR. FIFNAM(IIF,KF) .EQ. 'D' ) ) FCVLAIF = .FALSE.
               IF( VLAVR(KS) .AND. ( FIFNAM(IIF,KF) .EQ. 'C'
     1           .OR. FIFNAM(IIF,KF) .EQ. 'D' ) ) FCVLAIF = .FALSE.
               IF( VLAVL(KS) .AND. ( FIFNAM(IIF,KF) .EQ. 'A'
     1           .OR. FIFNAM(IIF,KF) .EQ. 'B' ) ) FCVLAIF = .FALSE.
            END IF
C
C           If it is the VLBA, be sure of the front end spec.  This 
C           is a bit complicated because we need to detect the
C           index number of the IF, as used in setup parameters, 
C           based on the name.
C
C           This is for FE only at the moment and that applies
C           only to certain stations (VLBA).  Hence we don't have to
C           test against MarkIV or other IF names.
C
            IFINDX = 0
            IF( FIFNAM(IIF,KF) .EQ. 'A' ) IFINDX = 1
            IF( FIFNAM(IIF,KF) .EQ. 'B' ) IFINDX = 2
            IF( FIFNAM(IIF,KF) .EQ. 'C' ) IFINDX = 3
            IF( FIFNAM(IIF,KF) .EQ. 'D' ) IFINDX = 4
C
C           If not found for stations that need it, die.  Otherwise
C           set a benign default.
C
            IF( IFINDX .EQ. 0 ) THEN
               IF( INDEX( SETSTA(1,KS), 'VLBA' ) .NE. 0 ) THEN
                  CALL ERRLOG( 'FCOMPARE: Unrecognized IF name for '
     1               // SETSTA(1,KS) // ' in frequency catalog.' )
               ELSE
                  IFINDX = 1
               END IF
            END IF
C
C           Now finally test against the FE specification on VLBA
C           stations.
C
            IF( INDEX( SETSTA(1,KS), 'VLBA' ) .NE. 0 ) THEN 
               FCFE =  ( FE(IFINDX,KS) .EQ. 'omit' .OR.
     1             FE(IFINDX,KS) .EQ. FFE(IIF,KF) )
            ELSE
               FCFE = .TRUE.
            END IF
C
C           Add up all the tests.
C
            IFMATCH = FCIFCH .AND. FCFLO1 .AND. FCPOL .AND. FCCH1
     1           .AND. FCVLAIF .AND. FCFE .AND. RFCLOSE
C
C           If the channel matches, other than in the precise frequency,
C           record that fact.  OKIF means all except maybe the exact
C           frequency matches.
C
            IF( IFMATCH ) THEN
               OKIF(ICH,IIF) = .TRUE.
            END IF
C
C           Check for exact frequency in range.  Only require one 
C           channel to be ok - allows for overflow at places like 
C           the VLA.
C           If the routine got past the top few statements, at least
C           one channel is in the frequency range.  Check this specific
C           channel here, but don't let a mismatch prevent an overall
C           match.  Just try to downgrade this option so if a better
C           one exists, it will be used.
C
            FREQOK(ICH) = FREQREF(ICH,KS) .GE. FRF1(IIF,KF) .AND.
     1                    FREQREF(ICH,KS) .LE. FRF2(IIF,KF)
C
C           Record if there are any matching channels.  This means that
C           the freq.dat record can be used.
C
            IF( IFMATCH .AND. FREQOK(ICH) ) MATCH = .TRUE.
C
C           Determine just how bad the match was.
C
            IIFBAD = 0
            IF( .NOT. FCSTA )   IIFBAD = IIFBAD + 1
            IF( .NOT. RFCLOSE ) IIFBAD = IIFBAD + 1
            IF( .NOT. FCIFCH )  IIFBAD = IIFBAD + 1
            IF( .NOT. FCFLO1 )  IIFBAD = IIFBAD + 1
            IF( .NOT. FCPOL )   IIFBAD = IIFBAD + 1
            IF( .NOT. FCCH1 )   IIFBAD = IIFBAD + 1
            IF( .NOT. FCVLAIF ) IIFBAD = IIFBAD + 1
            IF( .NOT. FCFE )    IIFBAD = IIFBAD + 1
            IF( .NOT. FREQOK(ICH) )  IIFBAD = IIFBAD + 1
C
C           See if this was the best IF for this channel, save
C           number of mismatches and flags for printout.
C
            IF( IIFBAD .LT. CHBAD ) THEN
               CHBAD = IIFBAD
               WRITE( CHFLAGS, '( I2, 8L1 )' ) IIF, FCIFCH, 
     1            FCFLO1, FCPOL, FCCH1, FCVLAIF, FCFE, 
     2            FREQOK(ICH), RFCLOSE
            END IF
C
C           End of frequency group IF loop.
C
         END DO
C
C        Pring some current results if in debug mode.
C
         IF( SDEBUG ) THEN
            SETMSG = ' '
            WRITE( SETMSG, '( A, 3I4, 2X, 2L1 )' ) 
     1           'FCOMPARE: Channel checked: ', 
     2           KS, KF, ICH, MATCH
            CALL WLOG( 0, SETMSG )
         END IF
C
C        Get the degree by which the worst channel missed.
C
         KFBAD = MAX( KFBAD, CHBAD )
C
C        Some output if debugging or trying to explain why no
C        match was found (call with PRTMISS set true).
C
         IF( SDEBUG .OR. ( PRTMISS .AND. CHBAD .LE. NBAD + 1) ) THEN
            SETMSG = ' '
            WRITE( SETMSG, '( 3X, A12, I8, 6X, A2, 1X, ' //
     1         ' 8( 5X, A1 ) )' )
     2         FRNAME(KF), ICH, CHFLAGS(1:2),(CHFLAGS(I:I),I=3,10)
            CALL WLOG( 0, SETMSG )
         END IF
C
C        End of channel loop.
C
      END DO
C
C     Separate frequency sets in the table (print cosmetics).
C
      IF( SDEBUG .OR. PRTMISS ) THEN
         CALL WLOG( 0, ' ' )
      END IF
C
C     Some more debug printout.
C
      IF( SDEBUG ) THEN
         SETMSG = ' '
         WRITE( SETMSG, '( A, L1 )' ) 'FCOMPARE: Out of loop: ', 
     1        MATCH
         CALL WLOG( 0, SETMSG )
      END IF
C
C     Check 50 cm filter.  Maybe use FC50 some day related NBAD.
C
      FC50 =  SETSTA(1,KS)(1:4) .NE. 'VLBA' .OR. (
     1        ( RCP50CM(KS) .EQ. 'DEF' .OR.
     2        RCP50CM(KS) .EQ. FRCP50CM(KF) )  .AND.
     3        ( LCP50CM(KS) .EQ. 'DEF' .OR.
     4        LCP50CM(KS) .EQ. FLCP50CM(KF) ) )
C
      IF( ( MATCH .AND. .NOT. FC50 ) .AND. ( SDEBUG .OR. 
     1    (  PRTMISS .AND. KFBAD .LE. NBAD + 1) ) ) THEN
         CALL WLOG( 0, '          50cm filter doesn''t match.' )
      END IF
C
      MATCH = MATCH .AND. FC50
C
C     Record how bad the miss was.
C
      NBAD = MIN( NBAD, KFBAD )
C
C     Check the synthesizer settings for VLBA sites.  Allow the user
C     to set a synthesizer the frequency catalog doesn't care about
C     to anything.  Note that MATCH in the IF statement insures that 
C     the MATCH = statement is equivalent to MATCH = MATCH .AND. ...
C
      IF( SETSTA(1,KS)(1:4) .EQ. 'VLBA' .AND. MATCH ) THEN
         MATCH = ( SYNTH(1,KS) .EQ. 0.0 .OR. FSYN(1,KF) .EQ. 0.0 .OR.
     1             SYNTH(1,KS) .EQ. FSYN(1,KF) ) .AND.
     2           ( SYNTH(2,KS) .EQ. 0.0 .OR. FSYN(2,KF) .EQ. 0.0 .OR.
     3             SYNTH(2,KS) .EQ. FSYN(2,KF) ) .AND.
     4           ( SYNTH(3,KS) .EQ. 0.0 .OR. FSYN(3,KF) .EQ. 0.0 .OR.
     5             SYNTH(3,KS) .EQ. FSYN(3,KF) )
C
         IF( SDEBUG ) THEN
            IF( MATCH ) THEN
               CALL WLOG( 0, 'FCOMPARE: Synth matches.' )
            ELSE
               CALL WLOG( 0, 'FCOMPARE: Problem with synth matches.' )
            END IF
         END IF
C
      END IF
C
C     Check the VLA parameters.  Note that many unset parameters
C     will be set in VLASETF.  Note that MATCH in the IF statement  
C     insures that the MATCH = statement is equivalent to 
C     MATCH = MATCH .AND. ...
C
      IF( SETSTA(1,KS)(1:3) .EQ. 'VLA' .AND. MATCH ) THEN
         MFLKA = FLUKEA(KS) .EQ. 0.D0 .OR. FLUKEA(KS) .EQ. FVFLKA(KF)
         MFLKB = FLUKEB(KS) .EQ. 0.D0 .OR. FLUKEB(KS) .EQ. FVFLKB(KF)
         MFEAB = VLAFEAB(KS) .EQ. 0.D0 .OR. VLAFEAB(KS) .EQ. FVFEAB(KF)
         MFECD = VLAFECD(KS) .EQ. 0.D0 .OR. VLAFECD(KS) .EQ. FVFECD(KF)
         MSYNA = VLASYNA(KS) .EQ. 0.D0 .OR. VLASYNA(KS) .EQ. FVSYNA(KF)
         MSYNB = VLASYNB(KS) .EQ. 0.D0 .OR. VLASYNB(KS) .EQ. FVSYNB(KF)
         MFEF  = FEFILTER(KS).EQ.'ZZZZ' .OR. FEFILTER(KS).EQ.FVFILT(KF)
         MVBND = VLABAND(KS) .EQ. 'ZZ' .OR. VLABAND(KS) .EQ. FVBAND(KF)
         MVBW  = VLABW(KS) .EQ. 'ZZZZ' .OR. VLABW(KS) .EQ. FVBW(KF)
C
         MATCH =  MFLKA .AND. MFLKB .AND. MFEAB .AND. MFECD .AND. 
     1            MSYNA .AND. MSYNB .AND. MFEF .AND. MVBND .AND. MVBW
C
         IF( PRTMISS .OR. SDEBUG ) THEN
            IF( MATCH ) THEN
               CALL WLOG( 0, 'FCOMPARE: VLA stuff matches.' )
            ELSE
               CALL WLOG( 0,'FCOMPARE: The problem is with the match '
     1             // 'of VLA parameters (F indicates mismatch):' )
               CALL WLOG( 0, '     FLUKEA   FLUKEB  VLAFEAB  VLAFECD  '
     1            // 'VLASYNA  VLASYNB FEFILTER  VLABAND    VLABW' )
               SETMSG = ' '
               WRITE( SETMSG, '( 9( 8X, L1 ) )' ) 
     1             MFLKA, MFLKB, MFEAB, MFECD, MSYNA, MSYNB,
     2             MFEF, MVBND, MVBW
C
C              For ptlink.key, this bit of code is reached and it sees
C              the difference between XX and VX VLAMODE.  In older 
C              versions, it didn't get here because some IFs didn't
C              match.  Now that is allowed and MATCH is still true,
C              so it gets here.  This comment can probably be deleted 
C              once the new programming is done.
C
               CALL WLOG( 0, SETMSG )
            END IF
         END IF
      END IF
      IF( SDEBUG ) THEN
         IF( MATCH ) THEN
            CALL WLOG( 0, 'FCOMPARE: Got overall match.' )
         ELSE
            CALL WLOG( 0, 'FCOMPARE: Problem with overall  match.' )
         END IF
      END IF
C
C     Now we are done and MATCH = .TRUE. means that this frequency
C     group is compatible with the setup file in every way except
C     possibly the RF frequency of some channels.  
C
C     Jump here if no frequencies match to minimize time spent on
C     useless frequency sets.      
C
 1000 CONTINUE
      RETURN
      END

