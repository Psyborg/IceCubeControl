//*********************************************************************
// Steuerung für Eiswürfelbereiter SD20 (SIMAG)
// --------------------------------------------
// Datum: 3.8.2011
// Zielplattform: Arduino, alternativ C-Control
// Dei Steuerung soll die mechanische Nockensteuerung ersetzen.
// Dadurch lassen sich Parameter flexibler einstellen.
//
// Geplante Features:
//  - Serielle Ausgabe von Statusmeldungen
//  - Einstellbare Parameter per USB/EEPROM
//  - Ausgabe von Statusmeldungen auf dem LCD
//  - Einstellung der Parameter mit Bedientasten
//  - Betriebsstundenzähler
//
// TODO:
//  - Timerüberlauf abfangen
//
// Size: 3008 bytes
//*********************************************************************/

#define FIRMWAREVERSIONSTRING "V 0.1b"

// Variablendefinition
unsigned int step = 0;					// Schrittnummer
unsigned long time1, starttime_freeze, starttime_defrost = 0;	// Startzeit Freeze-Zyklus (Step 3)
unsigned long duration_freeze, duration_defrost; 

const int Kompressor = 6;
const int Wasserpumpe = 7;
const int Wasserventil = 8;
const int Heissgasventil = 9;
const int Luefter = 10;
const int HeartbeatLED = 13;
const int binsenspin = A0;
const int evapsenspin = A1;

boolean reinigungsschalter;

// Konstanten
#define TIME_WATERINLET 20000	// Wassereinlauf bei Gerätestart: 20 Sekunden
#define TIME_FREEZE 1080000		// 18 min * 60 s * 1000 ms = 1080000ms, Bildung der Eiswürfel
#define TIME_DEFROST 180000		// Abtauzeit: 3min * 60s * 1000ms = 180000ms

#define TEMP_BINFULL 0			// Speichertemperatur, Wert???
#define TEMP_EVAPORATOR -5		// Verdampfertemperatur, Wert???
#define ON 1
#define OFF 0

#include <LiquidCrystal.h>

LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

void setup()
{
  // set up the LCD's number of columns and rows: 
  lcd.begin(16, 2);
  // Print a message to the LCD.
  lcd.print("IceCube Control");
  lcd.setCursor(0,1);
  lcd.print(FIRMWAREVERSIONSTRING);
  delay(400);

  digitalWrite(HeartbeatLED, HIGH);
  pinMode(Kompressor, OUTPUT);  // Kompressor
  pinMode(Wasserpumpe, OUTPUT);  // Wasserpumpe
  pinMode(Wasserventil, OUTPUT);  // Wasserventil
  pinMode(Heissgasventil, OUTPUT);  // Heissgasventil
  pinMode(Luefter, OUTPUT);  // Lüfter
  pinMode(HeartbeatLED, OUTPUT);  // Heartbeat-LED
  /* Ports definieren
   	
   	Digital IN
   		- Reinigungsschalter
   		- Sicherheitsthermostat
   	
   	Analog IN
   		- Verdampfertemperatur
   		- Speichertemperatur
   		
   	Optional
   		- LCD
   		- Bedientasten
   	*/

  // Gerät für ersten Durchlauf vorbereiten
  digitalWrite(Kompressor, LOW);
  digitalWrite(Wasserpumpe, LOW);
  digitalWrite(Wasserventil, HIGH);
  digitalWrite(Heissgasventil, LOW);
  digitalWrite(Luefter, LOW);

  delay(TIME_WATERINLET);

  step = 1;
}

void loop()
{	
  digitalWrite(HeartbeatLED, !digitalRead(HeartbeatLED));

  
  
  // Kühlkreislauf auf Temperatur bringen, sodass die Eisbildung beginnt
  if (step == 1)
  { 
    lcd.setCursor(0,0);
    lcd.print("Beginne Kühlung ");
    
    digitalWrite(Wasserventil, OFF);
    digitalWrite(Wasserpumpe, ON);
    digitalWrite(Luefter, ON);
    digitalWrite(Kompressor, ON);
    digitalWrite(Heissgasventil, OFF);

    if (analogRead(evapsenspin) >= TEMP_EVAPORATOR)	// Eisbildung beginnt
    {
      duration_freeze = TIME_FREEZE;
      starttime_freeze = millis();	// Startzeitpunkt ermitteln
      step = 2;			// Weiter zum nächsten Step
      lcd.clear();
    }
  }

  // Eiswürfelbildung  wie eingestellte Zeit
  if (step == 2)
  {
    lcd.print("Kühlung läuft...");
    lcd.setCursor(0,1);
    lcd.print( (starttime_freeze + duration_freeze - millis() ) / 1000);
    
    if ( millis() - starttime_freeze >= duration_freeze )
    {
      duration_defrost = TIME_DEFROST;
      starttime_defrost = millis();	// Startzeitpunkt ermitteln
      step = 3;
      lcd.clear();
    }
  }

  // Abtauen
  if (step == 3)
  {
    digitalWrite(Wasserpumpe, OFF);
    digitalWrite(Heissgasventil, ON);
    digitalWrite(Wasserventil, ON);
    digitalWrite(Kompressor, ON);
    digitalWrite(Luefter, OFF);		

    if (millis() >= starttime_defrost + TIME_DEFROST )
    {
      step = 1;		// Beginne von vorne
      if (analogRead(binsenspin) <= TEMP_BINFULL)
      {
        step = 4;	// Speicher voll
      }
      if (reinigungsschalter)
      {
        step = 5;	// Reinigung
      }
    }
  }

  // Speicher voll
  if (step == 4)
  {
    digitalWrite(Kompressor, OFF);
    digitalWrite(Luefter, OFF);
    digitalWrite(Wasserventil, OFF);
    digitalWrite(Heissgasventil, OFF);
    digitalWrite(Wasserpumpe, OFF);

    if (analogRead(binsenspin) > TEMP_BINFULL)
    {
      step = 1;
    }
  }

  // Reinigung
  if (step == 5)
  {
    digitalWrite(Kompressor, OFF);
    digitalWrite(Luefter, OFF);
    digitalWrite(Wasserventil, OFF);
    digitalWrite(Heissgasventil, OFF);
    digitalWrite(Wasserpumpe, ON);
    if (!reinigungsschalter)
    {
      step = 1;
    }
  }
  
  // Abfang Step-Coounter
  if (step >= 6 | step <= 0)
  {
    step = 1;
  }
  // Timerüberlauf von millis() abfangen!!!
  delay(100);
}


