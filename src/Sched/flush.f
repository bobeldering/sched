      SUBROUTINE FLUXH( IUNIT, FFILE )
C
C     Spelled FLUXH because FLUSH seems to be an intrinsic in GNU 
C     FORTRAN (others?).
C
C     Utility routine to flush the buffers of a text file.
C     This makes it reasonable to read the file before the program
C     is really done with it.
C
C     If anyone knows a better way to do this in FORTRAN, let me know.
C
      INTEGER    IUNIT, IERR, VLBOPE
      CHARACTER  FFILE*(*), OPTEXT*(256), LOCFILE*(256)
C ----------------------------------------------------------------------
C
C     Required by some compilers for concatenations:
C
      LOCFILE = FFILE
C
C     Close the file.
C
      CLOSE( UNIT = IUNIT )
C
C     Now open it again.
C
      IERR = VLBOPE( IUNIT, FFILE, 'TEXT', 'OLD', OPTEXT )
      IF( IERR .NE. 1 ) THEN 
         WRITE(*,*) 'FLUSH: CANNOT REOPEN FILE ' // LOCFILE
         WRITE(*,*) '       Error text: ' // OPTEXT 
         CALL ERROR( ' Check why file cannot be opened' )
      END IF
C
C     Read to the end.
C
  100 CONTINUE
         READ( UNIT = IUNIT, FMT = '( A )', END = 200 ) OPTEXT
         GO TO 100
  200 CONTINUE
C
      RETURN
      END
