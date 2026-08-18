#include <Adafruit_MCP4725.h>
#include <Adafruit_ICM20X.h>
#include <Adafruit_ILI9341.h>
#include <boogaloo.h> //remove kindly before compiling used to test the resolver
void setup()
{
  Serial.begin(9600);
}

void loop()
{
  Serial.println("are momin :V");
  delay(1000);
}
