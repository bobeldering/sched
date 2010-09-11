      SUBROUTINE GEOMAKE( LASTISCN, JSCN, ISCN, SEGSRCS, NSEG,
     1                    GSTASCN, GSTARTJ )
C
C     Routine for SCHED called by ADDGEO that makes a list
C     of sources from the list of geo sources to fit into a
C     geodetic segment at the time of a scan for which such
C     a request was made.
C
C     The basic plan:
C        Loop through trial lists of sources.
C           Choose by random number generator.
C               Don't use previously used source
C               Keep track of sources that are not up and don't use.
C           Calculate a quality measure.
C               Like RMS spanned Sec(Z) of antenna with worst value.
C               Make it  SUM( (SEC(Z) - MEAN(SEC(Z)) )**2 
C                  Don't divide by number of scans so we can favor
C                  groups with more scans.
C        Keep a record of the best sequence (in SEGSRCS).
C            Replace SEGSRCS if a better sequence is found.
C
C        For each set, just stuff the scans into the scans starting
C        with ISCN.  JSCN is the template scan - less than SCAN1.
C
C     Some day, inhibit getting too close to the Sun.
C
      INCLUDE   'sched.inc'
C
      INTEGER           LASTISCN(*), JSCN, ISCN, SEGSRCS(*), NSEG
      LOGICAL           GSTASCN(MSEG,MAXSTA)
      DOUBLE PRECISION  GSTARTJ(*)
C
      INTEGER           MAXPAR
      PARAMETER         (MAXPAR=MAXSTA*2)
C
      INTEGER           ISEG, ITRIAL, LSCN, I, J, IDUM, ISTA, NSTSCN
      INTEGER           NTSEG, TSRC(MSEG)
      INTEGER           MINSPS, HALFSCNS, NPRT, ICH,  USEGEO(MGEO)
      REAL              BESTQUAL, TESTQUAL
      REAL              RAN5, DUMMY, SEGELEV(MAXSTA,MGEO)
      LOGICAL           OKGEO(MGEO), PRDEBUG, RETAIN, KEPT
      DOUBLE PRECISION  TGEO1, TGEOEND, STARTB, SIGMA(MAXPAR)
C
      DATA              IDUM   / -12345 /
      SAVE              IDUM
C ---------------------------------------------------------------------
      IF( DEBUG .OR. GEOPRT .GE. 2 ) CALL WLOG( 1, 'GEOMAKE starting.' )
      NPRT = MIN( 20, NSTA )
C
      BESTQUAL = 9999.
      DO ISEG = 1, MSEG
         SEGSRCS(ISEG) = 0
      END DO
      KEPT = .FALSE.
C
C     Prime the random number generator a bit.  I don't know
C     if this is needed, but without it, the first antenna choices
C     didn't seem too random.
C
      DO I = 1, 100
         DUMMY = RAN5(IDUM)
      END DO
C
C     Save some parameters related to the block of scans.
C     This is mainly the start and stop times.  Take as the
C     beginning of the block the latest end of the previous
C     scan at any station. 
C
      TGEO1 = 0.D0
      DO ISTA = 1, NSTA
         IF( STASCN(JSCN,ISTA) ) THEN
            IF( LASTISCN(ISTA) .NE. 0 ) THEN
               TGEO1 = MAX( TGEO1, STOPJ(LASTISCN(ISTA)))
            ELSE
               TGEO1 = MAX( TGEO1, TFIRST )
            END IF
         END IF
      END DO
C
      STARTB = TGEO1
      TGEOEND = TGEO1 + GEOLEN(ISCN)
C
      IF( GEOPRT .GE. 2 ) THEN
         WRITE(*,*) 'GEOMAKE START TIMES', STARTB, STARTJ(ISCN), TGEOEND
      END IF
C
C     Warn about inappropriate OPMIAN, then set one.
C
      IF( OPMIAN(JSCN) .LT. 2 ) THEN
         MSGTXT = ' '
         WRITE( MSGTXT, '( A, I4, A )' ) 
     1     'GEOMAKE:  OPMINANT of ', OPMIAN(JSCN), 
     2     ' too small for automatic insertion of geodetic sections.'
         CALL WLOG( 1, MSGTXT ) 
         MSGTXT = ' '
         OPMIAN(JSCN) = NSTA / 2
         WRITE( MSGTXT, '( A, I4 )' ) 
     1     '          Resetting to OPMINANT = ', OPMIAN(JSCN)
         CALL WLOG( 1, MSGTXT ) 
         MSGTXT = ' '
      END IF
C
C     Look at all sources to see if they can be used and if they
C     seem useful enough to be favored.  Get a list of elevations.
C
      CALL GEOCHK( JSCN, ISCN, STARTB, TGEOEND, OKGEO, USEGEO,
     1             SEGELEV )
C
C     The idea now is to make a bunch of possible sequences and test
C     their quality using the algorithm in geoqual.  There are two
C     parts of this process that are a bit tricky.  The first is 
C     selecting the sequences to try.  The second is the quality 
C     measure.  See GEOQUAL for details the quality measure in use.
C
C     Loop over the trials.  For now, the number is hardwired.  That
C     will likely be pulled out as a user parameter some day.
C
      DO ITRIAL = 1, GEOTRIES
         IF( GEOPRT .GE. 1 ) CALL WLOG( 1, ' ' )
         IF( GEOPRT .GE. 0 ) THEN
            MSGTXT = ' '
            WRITE( MSGTXT, '( A, I5, A, I5 )' ) 
     1           'GEOMAKE starting to construct trial segment', 
     2           ITRIAL, '.  First scan: ', ISCN
            CALL WLOG( 1, MSGTXT )
         END IF
C
C        Make a sequence of scans for the geodetic block.
C
         CALL MAKESEG( JSCN, ISCN, LASTISCN, 
     1                 OKGEO, USEGEO, SEGELEV, STARTB, TGEOEND, 
     2                 LSCN, NTSEG, TSRC, IDUM, SIGMA )
C
C        Make sure each antenna is in a reasonable number of scans.
C        There is some hoop jumping because the number of scans can
C        vary.   Only test stations that are in the template JSCN.
C        MINSPS is "Minimum Scans Per Station".  Meanwhile, protect
C        against any station with only one scan (A short geoseg 
C        combined with long slews might create such a case).
C
         HALFSCNS = MAX( INT( ( LSCN - ISCN + 1.0 ) / 2.0 + 0.6 ),
     1                   2 )
         MINSPS = 9999
         DO ISTA = 1, NSTA
            IF( STASCN(JSCN,ISTA) ) THEN
               NSTSCN = 0
               DO I = ISCN, LSCN
                  IF( STASCN(I,ISTA) ) THEN
                     NSTSCN = NSTSCN + 1
                  END IF
               END DO
               MINSPS = MIN( MINSPS, NSTSCN )
            END IF
         END DO
C
C                       Programming warning:
C
C                       This is a potential source of trouble if
C                       slow stations are getting left out.
C                       It used to test against being in half of the
C                       scans, but that could be a problem when
C                       slow stations are being left out of scans.
C                       So for now, just test against a minimum number
C                       to get a solution.
C
C         RETAIN = MINSPS .GE. HALFSCNS
         RETAIN = MINSPS .GE. 3
C
C        For kept sequences, test the quality.
C
         IF( RETAIN ) THEN
C
            IF( GEOPRT .GE. 2 ) THEN
               WRITE(*,*) 'GEOMAKE ---------------------------------- '
               WRITE(*,'( A, I4, A, 30I3 )' ) 
     1              'GEOMAKE    FINISHED ONE SEQUENCE - Trial:', 
     2               ITRIAL, ' Geosrcs:', (TSRC(ISEG), ISEG=1,NTSEG)
            END IF
C
C           Get the quality measure of scans ISCN to LSCN.  Isolate this
C           to a subroutine in case someone wants to brew their own measure.
C           Here continue to reward arbitrarily low elevation scans (0.0
C           after JSCN).
C        
            PRDEBUG = GEOPRT .GE. 2
            CALL GEOQUAL( ISCN, ISCN, LSCN, JSCN, 0.0, 
     1                    TESTQUAL, PRDEBUG, SIGMA )
C
C           Provide some feedback on the current segment.
C
            IF( GEOPRT .GE. 0 ) THEN
               MSGTXT = ' '
               WRITE( MSGTXT, '( A, A, I5, A, F7.2, A, F7.2 )') 
     1                'GEOMAKE: Finished making a segment. ',
     2                ' Number of scans:', ntseg, '  Quality:', 
     3                TESTQUAL, '  Previous best:', BESTQUAL
               CALL WLOG( 1, MSGTXT )
               MSGTXT = ' '
               WRITE( MSGTXT,'( A, 20I3 )' )  '     Sources:   ', 
     1               (TSRC(ISEG),ISEG=1,NTSEG)
               CALL WLOG( 1, MSGTXT )
               MSGTXT = ' '
               WRITE( MSGTXT,'( A, 20I3 )' )  '     Priority:  ', 
     1               (USEGEO(TSRC(ISEG)),ISEG=1,NTSEG)
               CALL WLOG( 1, MSGTXT )
               MSGTXT = ' '
               WRITE( MSGTXT, '( A, 20F5.1 )' ) 
     1              '     Sigmas by station: ', 
     2              (SIGMA(ISTA),ISTA=1,NPRT)
               CALL WLOG( 1, MSGTXT )
            END IF
C        
C           See whether to save this one source set.
C        
            IF( TESTQUAL .LT. BESTQUAL ) THEN
C
C              Annouce that a new best was found.
C
C               IF( GEOPRT .GE. 0 ) THEN
                  IF( GEOPRT .EQ. 0 ) WRITE(*,*) ' '
                  MSGTXT = ' '
                  WRITE( MSGTXT, '( A, I5, A, 2I3, A, F7.3 )' )
     1             'New best geodetic segment - Trial: ', ITRIAL, 
     2             ' Number of scans & fewest scans/sta: ', 
     3             NTSEG, MINSPS, '  Quality: ', 
     4             TESTQUAL
                  CALL WLOG( 1, MSGTXT )
C               END IF
C
C              Save the new sequence.  Note that STASCN will have
C              been set in ways to allow leaving slow antennas
C              out.  It should not be regenerated in a call to 
C              MAKESCN or whatever.  It is saved here because,
C              as more segments are tried, it will change.
C
               BESTQUAL = TESTQUAL
               DO ISEG = 1, NTSEG
                  I = ISCN + ISEG - 1
                  SEGSRCS(ISEG) = TSRC(ISEG)
                  GSTARTJ(ISEG) = STARTJ(I)
                  DO ISTA = 1, NSTA
                     GSTASCN(ISEG,ISTA) = STASCN(I,ISTA)
                  END DO
               END DO
               NSEG = NTSEG
               KEPT = .TRUE.
            END IF
         ELSE
            IF( GEOPRT .GE. 0 ) THEN
               CALL WLOG( 1, 'GEOMAKE: Segment not kept.' //
     1           '  Not enough scans at some stations.' )
            END IF
         END IF
C
C        If requested, write details about each trial sequence.
C
         IF( ( GEOPRT .GE. 0 .AND. KEPT ) .OR. GEOPRT .GE. 1 ) THEN
            MSGTXT = ' '
            WRITE(MSGTXT, '( A, I5, A, F7.2, A, 23I3 )' ) 
     1            'Trial ', ITRIAL, '  Quality:', 
     2            TESTQUAL, ' sources: ', (TSRC(I),I=1,NTSEG)
            CALL WLOG( 1, MSGTXT )
            MSGTXT = ' '
            WRITE( MSGTXT, '( A, 20( 4X, A2, 1X) )' ) 
     1           '                      ', 
     2           (STCODE(STANUM(ISTA)),ISTA=1,NPRT)
            CALL WLOG( 1, MSGTXT )
            IF( RETAIN ) THEN
               MSGTXT = ' '
               WRITE( MSGTXT, '( A, 20F7.2 )' ) 
     1              '   Sigmas by station: ', 
     2              (SIGMA(ISTA),ISTA=1,NPRT)
               CALL WLOG( 1, MSGTXT )
            ELSE
               CALL WLOG( 1, '  Rejected without testing.'//
     1            '  Some station(s) with too few scans.' )
            END IF
            DO I = 1, NTSEG
               J = ISCN + I - 1
               MSGTXT = ' '
               WRITE( MSGTXT,'( I4, 2X, A12, 20F5.0 )' ) TSRC(I), 
     1              GEOSRC(TSRC(I))
               ICH = 25
               DO ISTA = 1, NPRT
                  IF( STASCN(J,ISTA) ) THEN
                     WRITE( MSGTXT(ICH:ICH+10), '( F5.0, 1X )' )
     1                       EL1(J,ISTA)
                  ELSE
                     WRITE( MSGTXT(ICH:ICH+10), '( A, F4.0, A )' )
     1                       '(', EL1(J,ISTA), ')'
                  END IF
                  ICH = ICH + 7
               END DO
               CALL WLOG( 1, MSGTXT )
            END DO

         END IF
         KEPT = .FALSE.
         IF( MOD( ITRIAL, 10 ) .EQ. 0 ) THEN
            MSGTXT = ' '
            WRITE( MSGTXT, '( A, I5 )' ) 
     1           'Finished trial geodetic segment number ',
     2           ITRIAL
            CALL WLOG( 1, MSGTXT )
         END IF
      END DO
C
C     Write result
C
      IF( GEOPRT .GE. 0) THEN
         CALL WLOG( 1, '   ' )
         MSGTXT = ' '
         WRITE( MSGTXT, '( A, 30I3 )' ) 
     1          'GEOMAKE finished: Selected sources: ', 
     2         (SEGSRCS(ISEG), ISEG=1,NSEG)
         CALL WLOG( 1, MSGTXT )
      END IF
C
      RETURN
      END
