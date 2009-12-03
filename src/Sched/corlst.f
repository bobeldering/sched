      SUBROUTINE CORLST
C
C     Routine for SCHED that writes the correlator information
C     to the summary file.
C
      INCLUDE 'sched.inc'
      INCLUDE 'schset.inc'
C
      INTEGER           ISTA, ISCN, I, NSANT, NBAS, NPOL
      REAL              DATARATE, MAXSPD
      DOUBLE PRECISION  TTIME, TRTIME, TBTIME, STIME
      DOUBLE PRECISION  TIMEB, TIMEL, TLAST
      LOGICAL           OVERLAP
C
C     Note that MAXDR and DATASIZE are passed through the include
C     to the correlator specific routines and the OMS routines 
C     which must be called later.
C ------------------------------------------------------------------
C     Only do this if tapes are being used.
C
      IF( NOTAPE ) THEN
         WRITE( ISUM, '( 1X, /, A )' )
     1      'No tapes recorded.  Correlation requests ignored.'
      ELSE
         WRITE( ISUM, '( 1X, /, A, /, 1X, /,  9(A,/), 1X, /, ' // 
     1        ' 5(A,/), 1X, /, 5(A,/) )' ) ( CORSTUFF(I), I = 1, MCOR )
C
C        Get the parameters of the observation that are needed to get 
C        the data rates and volume.
C
C        Get the factor related to the polarization processing.
C
         NPOL = 1
         IF( CORPOL ) NPOL = 2
C
C        Initialize some accumulators.
C
         TTIME = 0.D0
         TRTIME = 0.D0
         TBTIME = 0.D0
         MAXDR = 0.0
         TIMEB = 1.D10
         TIMEL = 0.D0
         TLAST = 0.D0
         DATASIZE = 0.D0
         OVERLAP = .FALSE.
C
C        Loop through scans.
C
         DO ISCN = SCAN1, SCANL
C
C           Start and end times of experiment to determine elapsed time.
C
            TIMEB = MIN( TIMEB, STARTJ(ISCN) )
            TIMEL = MAX( TIMEL, STOPJ(ISCN) )
C
C           Get number of stations in the scan.
C
            NSANT = 0
            DO ISTA = 1, NSTA
               IF( STASCN(ISCN,ISTA) ) THEN
                  NSANT = NSANT + 1            
               END IF
            END DO
C
C           Get time in all scans, including non-recording scans.
C
            IF( NSANT .GT. 0 ) THEN
               STIME = ( STOPJ(ISCN) - STARTJ(ISCN) ) * 86400.D0
               TTIME = TTIME + STIME
            END IF
C
C           For scans recording data, get the time and the time 
C           multiplied by the number of baselines.  Look for signs
C           that the derived data volume will be wrong.
C
            IF( NSANT .GT. 0 .AND. .NOT. NOREC(ISCN) ) THEN
               STIME = ( STOPJ(ISCN) - STARTJ(ISCN) ) * 86400.D0
               NBAS = NSANT * ( NSANT - 1 ) / 2 + NSANT
               TRTIME = TRTIME + STIME
               TBTIME = TBTIME + STIME * NBAS
C
C              Test for backward time jumps.
C
               IF( STARTJ(ISCN) .LT. TLAST ) OVERLAP = .TRUE.
               TLAST = STOPJ(ISCN)
C
C              Get the data rate based on a Romney formula.
C              The data rate in bytes/sec is given APPROXIMATELY as
C              This is for the VLBA correlator, but is probably 
C              pretty close for any correlator.
C
C               4 * Ns * (Ns + 1) * Nc * Nsp * P * Su / Tavg
C
C               where Ns   = number of stations
C                     Nc   = number of (BaseBand) channels (1, ... 32)
C                     Nsp  = spectral resolution (8, 16, 32 ... 512)
C                     P    = 2 for polarization, 1 for none
C                     Su   = speed up factor (1, 2, 4)
C                    Tavg = time average in seconds
C
               IF( CORAVG .GT. 0.0 .AND. .NOT. NOSET ) THEN
                  DATARATE = 4.0 * NSANT * (NSANT+1) * 
     1                       MSCHN(SETNUM(ISCN)) * CORCHAN *
     2                       NPOL * FSPEED(SETNUM(ISCN)) / CORAVG
               ELSE
                  DATARATE = 0.0
               END IF
               MAXDR = MAX( MAXDR, DATARATE )
               MAXSPD = MAX( MAXSPD, FSPEED(SETNUM(ISCN)))
C
C              Accumulate the data size.  Note double precision - for 
C              multiple Gbytes, small numbers being added to large 
C              numbers might stop accumulating.
C
               IF( FSPEED(SETNUM(ISCN)) .NE. 0.0 ) THEN
                  DATASIZE = DATASIZE + DATARATE * STIME / 
     1                       FSPEED(SETNUM(ISCN))
               END IF
C
            END IF
         END DO
C
C        Now write the above results.
C
         WRITE( ISUM, '( 1X, /, A )' )
     1       'DERIVED INFORMATION FOR CORRELATION: '
         WRITE( ISUM, '( 1X, /, A, F8.2, A )' )
     1       '  Elapsed time for project:      ', 
     2        ( TIMEL - TIMEB ) * 24.D0, ' hours.'
         WRITE( ISUM, '( A, F8.2, A )' )
     1       '  Total time in scheduled scans: ', TTIME/3600.D0, 
     2       ' hours.'
         WRITE( ISUM, '( A, F8.2, A )' )
     1       '  Total time in recording scans: ', TRTIME/3600.D0, 
     2       ' hours.'
         WRITE( ISUM, '( A, F8.2, A )' )
     1       '  Total number of baseline hours:', TBTIME/3600.D0, 
     2       '    (Recording scans only)'
         WRITE( ISUM, '( A, F8.1, A, /, T10, A, F6.1 )' )
     1     '  Projected maximum data output rate from the correlator:',
     2       MAXDR/1000.0, ' kbytes/sec',
     3     ' if processed in one pass at a maximum speed up factor of',
     4     MAXSPD
         WRITE( ISUM, '( A, F9.1, A )' )
     1       '  Projected correlator output data set size:', 
     2       DATASIZE/1.D6, ' Mbytes'
         WRITE( ISUM, '( A )' )
     1       '    NOTE:  Above numbers assume the same correlator'//
     2       ' parameters are used for all data.'
         IF( DATASIZE .GT. 4.0E9 ) THEN
            WRITE( ISUM, '( A, A )' )
     1       '    NOTE:  Output data set size large.  ',
     2       'Consider requesting high density tapes.'
         END IF
C
C        Deal with correlator specific situations.  Only Socorro
C        for now.
C
         CALL CORSOC
C
C        Warn if there are reasons to believe the data rates are wrong.
C
         IF( OVERLAP ) THEN
            WRITE( ISUM, '( 1X, /, A, /, 4( A, / ) )' )
     1      ' **** WARNING *****', 
     2      '      Overlapping scans were detected.  Either there '//
     3            'was subarraying',
     4      '      or some stations were scheduled separtely from '//
     5            'others.',
     6      '      If the latter, the output data rates and volume '//
     7            'are underestimated',
     8      '      because the number of baselines is underestimated.'
C
C           I think any pointing scans should have NOREC set and so 
C           shouldn't trigger this warning.  But I'm leaving the code
C           here in case I'm missing something.
C
C            IF( AUTOPEAK ) THEN
C               WRITE( ISUM, '( A, /, A )' )
C     1         '      This might be due to inserted pointing scans '//
C     2               'in which case', 
C     3         '      there is no impact on data estimates.'
C            END IF
C
            WRITE( ISUM, '( 1X, / )' )
         END IF
      END IF
C
      RETURN
      END
