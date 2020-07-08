#include <Arduino.h>
#include <LCD_1602_RUS.h>
#include <Servo.h>
#include <Adafruit_NeoPixel.h>
#include <DFPlayer_Mini_Mp3.h>
#include <GyverEncoder.h>
#include <stdlib.h>
#include <time.h>

LCD_1602_RUS lcd(0x27, 16, 2); //Порт дисплея обычно 0x27 или 0x3F, подключение экрана А4-SDA-зеленый, А5-SCL-желтый

unsigned long currentTime;
unsigned long ledTime;


const byte CLK = 2;
const byte DT = 3;
const byte SW = 4;
Encoder enc(CLK, DT, SW);
boolean promivka = false;
//Массив , обозначаем подключенные оптопары по выводам . Оптопары подключены, A0,A1,A2,A3,A6
const byte Optics[] = {0, 1, 2, 3, 6};
// Значения порога срабатывания датчика для каждой рюмки
const unsigned int Optics_porog[] = {50, 50, 50, 50, 50};
//Серво
const int PIN_SERVO = 9;
Servo servo;
//Позиция каждой рюмки
const byte Rumka_pos[] = {35, 65, 94, 125, 150}; //12 - 48 - 90 - 135 - 174
const byte servo_speed = 20; // Скорость поворота серво,  10 - норм, 20 медленно, 30 очень медленно
byte Menu = 0;
byte MenuFlag = 0; // Здесь храниться уровень меню. 0 находимся в  Главном меню. 1 Вошли в меню Авто, 2 вошли в  Ручное управление
byte Drink = 20; // По умолчанию в рюмку наливаем  20 мл.
//----- Минимальные и максимальные значения наполняемой жидкости и задержки для наполнения.
const byte min_Drink = 10; // Минимум в рюмку - 10 мл.
const byte max_Drink = 50; // Максимум в рюмку - 50 мл.
// Калибровка работы насосика. Значения для налива min_Drink и max_Drink соотвественно
const unsigned int min_Drink_delay = 222;
const unsigned int max_Drink_delay = 5500;
//--------
byte DrinkCount = 1; //По умолчанию, для ручного режима - 1 рюмка
const byte max_DrinkCount = 5; //Максимальное кол-во рюмок - 5
// Насосик
const byte PIN_PUMP = 12;
// Светодиоды
const int PIN_LED = 5;// Сюда подключаются светодиоды
const int LED_COUNT = max_DrinkCount;
Adafruit_NeoPixel strip = Adafruit_NeoPixel(LED_COUNT, PIN_LED, NEO_GRB + NEO_KHZ800);

int BatPin = A7;    // пин контроля состояния батареи
float Value_volt = 0;

void pump_enable() {
    digitalWrite(PIN_PUMP, 1); //вкл реле
}

void pump_disable() {
    digitalWrite(PIN_PUMP, 0); //выкл реле
}

void pump_timer(byte Drink) {
    digitalWrite(PIN_PUMP, 1); //вкл реле
    delay(map(Drink, min_Drink, max_Drink, min_Drink_delay, max_Drink_delay));
    digitalWrite(PIN_PUMP, 0); //выкл реле
}

/**
 * CLEAR > < arrows
 */
void clearMenuArrows() {
    lcd.setCursor(0, 1);
    lcd.print(F(""));
    lcd.setCursor(15, 1);
    lcd.print(F(""));
}

void printMenuArrows() {
    lcd.setCursor(0, 1);
    lcd.print(F(">"));
    lcd.setCursor(15, 1);
    lcd.print(F("<"));
}

void oled_menu(byte Menu) {
    lcd.clear();
    lcd.setCursor(3, 0);
    lcd.print(F("НАЛИВАТОР+"));
    switch (Menu) {
        case 0:
            printMenuArrows();
            lcd.setCursor(6, 1);
            lcd.print(F("АВТО"));
            break;
        case 1:
            printMenuArrows();
            lcd.setCursor(2, 1);
            lcd.print(F("РУЧНОЙ РЕЖИМ"));
            break;
        case 2:
            printMenuArrows();
            lcd.setCursor(4, 1);
            lcd.print(F("ПРОМЫВКА"));
            break;
        case 3:
            clearMenuArrows();
            lcd.setCursor(1, 1);
            lcd.print(F("РУССКАЯ РУЛЕТКА"));
            break;
    }
}

//  выводит строчку по чуть чуть, в самый раз и тд. Передается номер строки, на которой выводить сообщение
void DrinkInfo(byte pos) {
    Serial.println(F("INFO_DRINK"));

    lcd.setCursor(0, 1);
    if (Drink < 15) {
//    lcd.setCursor(0, 1);
        lcd.print(F("    НИ О ЧЕМ    "));
    } else if (Drink < 20) {
//    lcd.setCursor(0, 1);
        lcd.print(F(" ПО ЧУТЬ - ЧУТЬ "));
    } else if (Drink < 30) {
//    lcd.setCursor(0, 1);
        lcd.print(F("  В САМЫЙ  РАЗ  "));
    } else if (Drink < 40) {
//    lcd.setCursor(0, 1);
        lcd.print(F("   ПО  ПОЛНОЙ  "));
    } else {
//    lcd.setCursor(0, 1);
        lcd.print(F("    ДО КРАЕВ    "));
    }
}

// Меню Авто режим
void oled_auto(int Drink) {
    Serial.println(F("MENU_AUTO"));
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(F("HАЛИТЬ ПО"));
    lcd.setCursor(10, 0);
    lcd.print(Drink);
    Serial.println(Drink);
    lcd.setCursor(13, 0);
    lcd.print(F("мЛ?"));
    DrinkInfo(57);
}

void oled_russian_roulette(int Drink) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(F("HАЛИТЬ ПО"));
    lcd.setCursor(10, 0);
    lcd.print(Drink);
    Serial.println(Drink);
    lcd.setCursor(13, 0);
    lcd.print(F("мЛ?"));
    DrinkInfo(57);
};

// Меню Ручной режим
void oled_manual(int DrinkCount, int Drink) {
    Serial.println(F("MENU_RUCHN"));
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(F("HАЛИТЬ ПО"));
    lcd.setCursor(10, 0);
    lcd.print(Drink);
    lcd.setCursor(13, 0);
    lcd.print(F("мЛ?"));
    Serial.println(Drink);
    lcd.setCursor(0, 1);
    lcd.print(F("   В   РЮМ"));
    lcd.setCursor(5, 1);
    lcd.print(DrinkCount);
    Serial.println(DrinkCount);
    if (DrinkCount == 1) {
        lcd.setCursor(10, 1);
        lcd.print(F("КУ     "));
    } else if (DrinkCount <= 4) {
        lcd.setCursor(10, 1);
        lcd.print(F("КИ     "));
    } else {
        lcd.setCursor(10, 1);
        lcd.print(F("ОК     "));
    }

}

// Меню налива
void oled_naliv(int MenuFlag, int Drink, int DrinkCount) {
    Serial.println(F("NALIVAIU"));
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(F("НАЛИВАЮ ПО"));
    lcd.setCursor(11, 0);
    lcd.print(Drink);
    Serial.println(Drink);
    lcd.setCursor(14, 0);
    lcd.print(F("мЛ"));
    lcd.setCursor(0, 1);
    lcd.print(F("   В"));
    lcd.setCursor(5, 1);
    lcd.print(DrinkCount);
    Serial.println(DrinkCount);
    lcd.setCursor(7, 1);
    lcd.print(F("РЮМКУ"));
}

void oled_random_naliv() {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(F("НАЛИВАЮ В"));
    lcd.setCursor(0, 1);
    lcd.print(F("СЛУЧАЙНУЮ РЮМКУ"));
}

void oled_random_nalito(int Drink) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(F("HАЛИТО "));
    lcd.print(Drink);
    lcd.print(F(" мЛ В"));
    lcd.setCursor(0, 1);
    lcd.print(F("СЛУЧАЙНУЮ РЮМКУ"));
}

// Меню налито
void oled_nalito(int MenuFlag, int Nalito, int Drink) {
    Serial.println(F("NALITO"));
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(F("HАЛИТО ПО"));
    lcd.setCursor(11, 0);
    lcd.print(Drink);
    Serial.println(Drink);
    lcd.setCursor(14, 0);
    lcd.print(F("мЛ"));
    lcd.setCursor(0, 1);
    lcd.print(F("   В"));
    lcd.setCursor(5, 1);
    lcd.print(Nalito);
    lcd.setCursor(7, 1);
    lcd.print(F("РЮМ"));
    Serial.println(Nalito);
    if (Nalito == 1) {
        lcd.setCursor(10, 1);
        lcd.print(F("КУ     "));
    } else if (Nalito <= 4) {
        lcd.setCursor(10, 1);
        lcd.print(F("КИ     "));
    } else {
        lcd.setCursor(10, 1);
        lcd.print(F("ОК     "));
    }

}

void Batery() { // процедура измерение напряжения
    Value_volt = (float) 5 / 1024 * analogRead(BatPin);

    if (Value_volt < 3.4) {
        strip.setPixelColor(5, strip.Color(255, 0, 0)); //CRGB::Red 0xFF0000 красный
    } else if (Value_volt < 3.5) {
        //strip.setPixelColor(4, strip.Color(255, 165, 0)); //CRGB::Orange 0xFFA500 оранжевый
        strip.setPixelColor(5, strip.Color(255, 69, 0)); //CRGB::OrangeRed  0xFF4500
    } else if (Value_volt < 3.6) {
        strip.setPixelColor(5, strip.Color(255, 255, 0)); //CRGB::Yellow 0xFFFF00 желтый
    } else if (Value_volt < 3.7) {
        strip.setPixelColor(5, strip.Color(0, 255, 0)); //CRGB::Lime 0x00FF00 зеленый
    } else if (Value_volt < 3.8) {
        strip.setPixelColor(5, strip.Color(0, 255, 255)); //CRGB::Aqua 0x00FFFF голубой
    } else if (Value_volt < 3.9) {
        strip.setPixelColor(5, strip.Color(0, 0, 255)); //CRGB::Blue 0x0000FF синий
    } else if (Value_volt < 4.0) {
        strip.setPixelColor(5, strip.Color(255, 0, 255)); //CRGB::Magenta 0xFF00FF фиолетовый
    } else {// >100% заряда
        strip.setPixelColor(5, strip.Color(75, 0, 130)); //CRGB::Indigo  0x4B0082

    }
    strip.show();
}

void Tost() { //Рандом - 1
    //Serial.println(F("Tost"));
    randomSeed(currentTime);
    byte num = random(18); // 0...21
    //Serial.println(num);
//mp3_set_volume (25);// устанвливаем громкость 25 (если хотите установить
//   кнопки для регулировки громкости вручную, закоментируйте эту и с
//ледующую строчку)
    delay(100);
    lcd.clear();
    switch (num) {
        //switch (random(20)) { // 0...19
        case 0: //ЗА ВСТРЕЧУ!
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));
            lcd.setCursor(2, 1);
            lcd.print(F("ЗА ВСТРЕЧУ!"));
            mp3_play(2);  // Проигрываем "mp3/0002.mp3"
            delay(100);
            break;
        case 1: //ЗА КРАСОТУ!
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));
            lcd.setCursor(2, 1);
            lcd.print(F("ЗА КРАСОТУ!"));
            mp3_play(3);  // Проигрываем "mp3/0003.mp3"
            delay(100);
            break;
        case 2: //"ЗА ДРУЖБУ!"
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));//
            lcd.setCursor(3, 1);
            lcd.print(F("ЗА ДРУЖБУ!"));
            mp3_play(4);  // Проигрываем "mp3/0004.mp3"
            delay(100);
            break;
        case 3: //"ЗА БРАТСТВО!
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));
            lcd.setCursor(2, 1);
            lcd.print(F("ЗА БРАТСТВО!"));
            mp3_play(5);  // Проигрываем "mp3/0005.mp3"
            delay(100);
            break;
        case 4: //ЗА СПРАВЕДЛИВОСТЬ!
            lcd.setCursor(5, 0);
            lcd.print(F("НУ, ЗА"));
            lcd.setCursor(1, 1);
            lcd.print(F("СПРАВЕДЛИВОСТЬ!"));
            mp3_play(6);  // Проигрываем "mp3/0006.mp3"11
            delay(100);
            break;
        case 5: //ЗА РЫБАЛКУ!
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));
            lcd.setCursor(3, 1);
            lcd.print(F("ЗА РЫБАЛКУ!"));
            mp3_play(7);  // Проигрываем "mp3/0007.mp3"
            delay(100);
            break;
        case 6: //ЗА ИСКУССТВО!
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));
            lcd.setCursor(2, 1);
            lcd.print(F("ЗА ИСКУССТВО!"));
            mp3_play(8);  // Проигрываем "mp3/0008.mp3"
            delay(100);
            break;
        case 7: //ЗА РАЗУМ!
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));
            lcd.setCursor(3, 1);
            lcd.print(F("ЗА РАЗУМ!"));
            mp3_play(9);  // Проигрываем "mp3/0009.mp3"
            delay(100);
            break;
        case 8: //ЗА ИСТИННЫХ ЖЕНЩИН!
            lcd.setCursor(5, 0);
            lcd.print(F("НУ, ЗА"));
            lcd.setCursor(0, 1);
            lcd.print(F("ИСТИННЫХ ЖЕНЩИН!!"));
            mp3_play(10);  // Проигрываем "mp3/0010.mp3"
            delay(100);
            break;
        case 9: //ЗА ПОНИМАНИЕ!
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));
            lcd.setCursor(2, 1);
            lcd.print(F("ЗА ПОНИМАНИЕ!"));
            mp3_play(11);  // Проигрываем "mp3/0011.mp3"
            delay(100);
            break;
        case 10: //ЗА ЕДИНЕНИЕ!
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));
            lcd.setCursor(2, 1);
            lcd.print(F("ЗА ЕДИНЕНИЕ!"));
            mp3_play(13);  // Проигрываем "mp3/0013.mp3"
            delay(100);
            break;
        case 11: //ЗА ПОБЕДУ!
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));
            lcd.setCursor(3, 1);
            lcd.print(F("ЗА ПОБЕДУ!"));
            mp3_play(16);  // Проигрываем "mp3/0016.mp3"
            delay(100);
            break;
        case 12: //ЗА РОДИНУ!
            lcd.setCursor(7, 0);
            lcd.print(F("НУ,"));
            lcd.setCursor(3, 1);
            lcd.print(F("ЗА РОДИНУ!"));
            mp3_play(21);  // Проигрываем "mp3/0021.mp3"
            delay(100);
            break;
        case 13: //ЧТОБ ГОЛОВА НЕ ТРЕЩАЛА!
            lcd.setCursor(0, 0);
            lcd.print(F("НУ, ЧТОБ ГОЛОВА"));
            lcd.setCursor(2, 1);
            lcd.print(F("НЕ ТРЕЩАЛА!"));
            mp3_play(17);  // Проигрываем "mp3/0017.mp3"
            delay(100);
            break;
        case 14: //ЗА СОЛИДНОЕ МУЖСКОЕ МОЛЧАНИЕ
            lcd.setCursor(0, 0);
            lcd.print(F("НУ, ЗА  СОЛИДНОЕ"));//НУ,
            lcd.setCursor(0, 1);
            lcd.print(F("МУЖСКОЕ МОЛЧАНИЕ!"));
            mp3_play(12);  // Проигрываем "mp3/0012.mp3"
            delay(100);
            break;
        case 15: //ЧТОБ МОРЩИЛО НАС МЕНЬШЕ!
            lcd.setCursor(0, 0);
            lcd.print(F("НУ,ЧТОБЫ МОРЩИЛО"));
            lcd.setCursor(2, 1);
            lcd.print(F("НАС МЕНЬШЕ ЧЕМ"));
            mp3_play(18);  // Проигрываем "mp3/0018.mp3"
            delay(100);
            break;
        case 16: //ЧТОБ В СТОРОНУ НЕ ВИЛЬНУЛО!
            lcd.setCursor(0, 0);
            lcd.print(F("НУ,ЧТОБ В СТОРО-"));
            lcd.setCursor(0, 1);
            lcd.print(F("НУ НЕ  ВИЛЬНУЛО!"));
            mp3_play(19);  // Проигрываем "mp3/0019.mp3"
            delay(100);
            break;
        case 17: //НУ ВЫ БЛИН ДАЁТЕ!
            lcd.setCursor(2, 0);
            lcd.print(F("НУ ВЫ БЛИН"));
            lcd.setCursor(5, 1);
            lcd.print(F("ДАЁТЕ!"));
            mp3_play(20);  // Проигрываем "mp3/0020.mp3"
            delay(100);
            break;
        case 18: //ЗА МИР ВО ВСЕМ МИРЕ
            lcd.setCursor(5, 0);
            lcd.print(F("ЗА МИР"));
            lcd.setCursor(2, 1);
            lcd.print(F("ВО ВСЕМ МИРЕ"));
            delay(2000);
            lcd.clear();
            lcd.setCursor(0, 0);
            lcd.print(F("И БОЛЬШИЕ СИСЬКИ"));
            lcd.setCursor(5, 1);
            lcd.print("!!!!");
            break;
        case 19: //ЗА НАС С ВАМИ
            lcd.setCursor(1, 0);
            lcd.print(F("ЗА НАС С ВАМИ"));
            lcd.setCursor(1, 1);
            lcd.print(F("И ХРЕН С НИМИ"));
            delay(100);
            break;
        case 20: //ЖЕЛАЮ ЧТОБЫ ВСЕ
            lcd.setCursor(0, 0);
            lcd.print(F("ЖЕЛАЮ ЧТОБЫ ВСЕ"));
            lcd.setCursor(5, 1);
            lcd.print(F("!!!!"));
            mp3_play(31);  // Проигрываем "mp3/0031.mp3"
            delay(100);
            break;
        case 21: //ХЛОПНУТЬ ПО РЮМАШКЕ
            mp3_play(37);  // Проигрываем "mp3/0031.mp3"
            lcd.setCursor(0, 0);
            lcd.print(F("А НЕ ХЛОПНУТЬ ЛИ"));
            lcd.setCursor(0, 1);
            lcd.print(F(" НАМ ПО РЮМАШКЕ?"));
            delay(3500);
            lcd.clear();
            lcd.setCursor(0, 1);
            lcd.print(F(" ЭТО ПРЕДЛОЖИЛ! "));
            lcd.setCursor(0, 0);
            lcd.print(F(" ЗАМЕТЬТЕ, НЕ Я "));
            break;
    }

    delay(2000);

}

void ServoNaliv(byte rumka) {
    servo.attach(PIN_SERVO);
    for (int pos = servo.read(); pos <= Rumka_pos[rumka]; pos += 1) {
        // с шагом в 1 градус
        servo.write(pos); // даем серве команду повернуться в положение, которое задается в переменной 'pos'
        delay(servo_speed); // ждем , пока ротор сервы выйдет в заданную позицию
    }
    servo.detach();

}

void ServoParking() {
    //Serial.println(servo.read());
    servo.attach(PIN_SERVO);
    for (int pos = servo.read(); pos >= 0; pos -= 1) {
        // с шагом в 1 градус
        servo.write(pos); // даем серве команду повернуться в положение, которое задается в переменной 'pos'
        delay(servo_speed); // ждем , пока ротор сервы выйдет в заданную позицию
    }
    servo.detach();
}

void CvetoMuzik() {
    for (int i = 0; i <= 7; i++) {
        for (int y = 0; y < max_DrinkCount; y++) {
            strip.setPixelColor(y, strip.Color(255, 0, 0));
            strip.show();
            delay(30);
        }
        for (int y = 0; y < max_DrinkCount; y++) {
            strip.setPixelColor(y, strip.Color(0, 255, 0));
            strip.show();
            delay(30);
        }
        for (int y = 0; y < max_DrinkCount; y++) {
            strip.setPixelColor(y, strip.Color(0, 0, 255));
            strip.show();
            delay(30);
        }
    }
}

void setup() {
    Serial.begin(9600);//
    enc.setType(TYPE2);
    //устанавливаем Serial порт МП3 плейера если вывод в монитор TX(D0) и RX(D1)не нужен
    mp3_set_serial(Serial);//инициализируем Serial порт МП3 плейера
    /*
    при необходимости создаем програмный порт для управдения МП3 плейером, если вывод в монитор TX(D0) RX(D1) необходим
    SoftwareSerial mySoftwareSerial(10, 11); // RX, TX  обозначаем програмный порт как mySoftwareSerial
    //плейер подключаем D10 D11
    mySoftwareSerial.begin(9600);//инициализируем програмный Serial порт
    mp3_set_serial (mySoftwareSerial);// указываем програмный порт для МП3 плейера
    //инициализируем Serial с скоростью 115200, если вывод в монитор  TX(D0) RX(D1) необходим
    Serial.begin(115200);
    */
    delay(100);//Между двумя командами необходимо делать задержку 100 миллисекунд, в противном случае некоторые команды могут работать не стабильно.
    mp3_set_volume(30);// устанавливаем громкость 30
    delay(100);
    mp3_play(60); // Проигрываем "mp3/0060.mp3"(0060_get started!.mp3)
    delay(100);
    lcd.init();// Инициализация дисплея
    lcd.backlight();
    lcd.setCursor(7, 0);
    lcd.print(F("НУ,"));
    lcd.setCursor(3, 1);
    lcd.print(F("ПОЕХАЛИИИИ!"));
    delay(3500);
    pinMode(BatPin, INPUT);
    pinMode(PIN_PUMP, OUTPUT);
    digitalWrite(PIN_PUMP, 0);
    currentTime = millis();
    //---------------
    oled_menu(0);
    strip.begin();
    for (int i = 0; i < 5; i++) {
        pinMode(Optics[i], INPUT);
    }
    ServoParking();
}

void loop() {
    enc.tick();
    currentTime = millis();

    //Вращение влево
    if (enc.isLeft()) {
        switch (MenuFlag) {
            case 0:
                (Menu <= 0) ? Menu = 3 : Menu--; // Перемещение курсора по главному меню назад
                oled_menu(Menu);
                break;
            case 1:
                (Drink <= min_Drink) ? Drink = max_Drink : Drink--; // Уменьшаем кол-во милилитров в рюмку
                oled_auto(Drink);
                break;
            case 2:
                (DrinkCount >= max_DrinkCount) ? DrinkCount = 1
                                               : DrinkCount++; // Влево увечичиваем рюмки для ручного режима
                oled_manual(DrinkCount, Drink);
                break;
            case 3:
                (Drink <= min_Drink) ? Drink = max_Drink : Drink--; // Уменьшаем кол-во милилитров в рюмку
                oled_russian_roulette(Drink);
                break;
        }
        //Вращение вправо
    } //else {
    if (enc.isRight()) {
        switch (MenuFlag) {
            case 0:
                (Menu >= 3) ? Menu = 0 : Menu++; // Перемещение курсора по главному меню вперед.
                oled_menu(Menu);
                break;
            case 1:
                (Drink >= max_Drink) ? Drink = min_Drink : Drink++;
                oled_auto(Drink);
                break;
            case 2:
                (Drink >= max_Drink) ? Drink = min_Drink : Drink++;
                oled_manual(DrinkCount, Drink);
                break;
            case 3:
                (Drink >= max_Drink) ? Drink = min_Drink : Drink++;
                oled_russian_roulette(Drink);
                break;
        }
    }


    //Обработка всех нажатий кнопки
    if (enc.isClick()) {// Нажата и отпущена кнопка
        if (Menu == 0 && MenuFlag == 0) { //Нажатие кнопки меню авто
            MenuFlag = 1;
            oled_auto(Drink);
            //} else if (MenuFlag == 1 && pause_sw > 20) { //Выход из меню авто в главное
            //MenuFlag = 0;
            //oled_menu(0);
        } else if (MenuFlag == 1) { //Начинается автоматический разлив
            //Serial.println("AUTO"); //Начало автоматического разлива
//mp3_set_volume (15);// устанавливаем громкость 15
//delay (100);
            mp3_play(99);  // Проигрываем бодренькую мелодию
            byte drink_count = 0;
            byte normal_drink_count = 1;
            for (int y = 0; y < max_DrinkCount; y++) {
                if (analogRead(Optics[y]) > Optics_porog[y]) {
                    int count = normal_drink_count++;
                    oled_naliv(MenuFlag, Drink, count); // Выводим на экран наливаем ...
                    strip.setPixelColor(y, strip.Color(255, 0, 0)); // Подствечиваем красным цветом
                    strip.show();
                    ServoNaliv(y); // Перемещяемся к рюмке
                    pump_timer(Drink); // Налив.
                    strip.setPixelColor(y, strip.Color(0, 255, 0)); // Подствечиваем зеленым , налито.
                    strip.show();
                    drink_count++;
                }
                mp3_stop;
            }
            if (drink_count > 0) {
                oled_nalito(MenuFlag, drink_count, Drink);
                ServoParking();
                delay(1000);
                Tost();
                CvetoMuzik();
                oled_auto(Drink);
            } else {
                lcd.setCursor(0, 0);
                lcd.print(F("   НЕТ РЮМОК!   "));
                lcd.setCursor(0, 1);
                lcd.print(F("ПОСТАВТЕ РЮМКИ! "));
                mp3_play(61);  // Проигрываем СТУК по люку.
                delay(2000);
                oled_auto(Drink);

            }
        } else if (Menu == 1 && MenuFlag == 0) { // Нажатие меню ручное
            MenuFlag = 2;
            oled_manual(DrinkCount, Drink);

        } else if (MenuFlag == 2) { //Начинается ручной разлив
            lcd.clear();
            lcd.setCursor(0, 0);
            lcd.print(F("А РЮМКИ ТОЧНО НА"));
            lcd.setCursor(0, 1);
            lcd.print(" СВОИХ МЕСТАХ?  ");
            mp3_play(62);  // Проигрываем ТАНК заводится.
            delay(5000);
            oled_naliv(MenuFlag, Drink, DrinkCount); // Выводим на экран наливаем ...
            for (int y = 0; y < DrinkCount; y++) {
                strip.setPixelColor(y, strip.Color(255, 0, 0)); // Подствечиваем красным цветом
                strip.show();
                ServoNaliv(y); // Перемещяемся к рюмке
                pump_timer(Drink); // Налив.
                strip.setPixelColor(y, strip.Color(0, 255, 0)); // Подствечиваем зеленым , налито.
                strip.show();
            }
            oled_nalito(MenuFlag, DrinkCount, Drink); // Выводим на экран налито ...
            ServoParking();
            Tost();
            CvetoMuzik();
            oled_manual(DrinkCount, Drink);
        } else if (Menu == 3 && MenuFlag == 0) { //Нажатие русская рулетка
            MenuFlag = 3;
            oled_russian_roulette(Drink);
        } else if (MenuFlag == 3) { //Разлив русская рулетка
            byte drink_count = 0;
            /**
             * Получаем количество стоящих рюмок
             */
            for (int y = 0; y < max_DrinkCount; y++) {
                if (analogRead(Optics[y]) > Optics_porog[y]) {
                    drink_count++;
                }
                mp3_stop;
            }
            /**
             * Запоминаем индекс стоящей стопки
             */
            int indexes[drink_count];
            int currentIndex = -1;
            for (int y = 0; y < max_DrinkCount; y++) {
                if (analogRead(Optics[y]) > Optics_porog[y]) {
                    currentIndex++;
                    indexes[currentIndex] = y;
                    Serial.println(indexes[currentIndex]);
                }
            }
            if (drink_count > 0) {
                int randomIndex = rand() % drink_count + 0; //Получаем случайную координату стопки от 0 до drink_count
                oled_random_naliv();
                strip.setPixelColor(indexes[randomIndex], strip.Color(255, 0, 0)); // Подствечиваем красным цветом
                strip.show();
                ServoNaliv(indexes[randomIndex]); // Перемещяемся к рюмке
                pump_timer(Drink); // Налив.
                strip.setPixelColor(indexes[randomIndex], strip.Color(0, 255, 0)); // Подствечиваем зеленым , налито.
                strip.show();
                oled_random_nalito(Drink);
                ServoParking();
                delay(1000);
                Tost();
                CvetoMuzik();
                oled_russian_roulette(Drink);
            } else {
                lcd.setCursor(0, 0);
                lcd.print(F("   НЕТ РЮМОК!   "));
                lcd.setCursor(0, 1);
                lcd.print(F("ПОСТАВТЕ РЮМКИ! "));
                mp3_play(61);  // Проигрываем СТУК по люку.
                delay(2000);
                oled_russian_roulette(Drink);

            }
        }
    }

    if (enc.isHolded()) {
        if (Menu == 2 && !promivka) {
            promivka = true;
            pump_enable(); // Включаем насос
            lcd.clear();
            lcd.setCursor(0, 0);
            lcd.print(F("П Р О М Ы В К А"));
            lcd.setCursor(2, 1);
            lcd.print(">>>>>>>>>>>>");
        } else if (MenuFlag == 1) { //Выход из меню авто в главное
            MenuFlag = 0;
            oled_menu(0);
        } else if (MenuFlag == 2) { //Выход из меню ручное в главное
            MenuFlag = 0;
            oled_menu(1);
        }
    }
    if (!enc.isHold() && promivka) {
        promivka = false;
        pump_disable(); //Выключаем насос
        oled_menu(2);
    }

    if (currentTime >= (ledTime + 300)) {
        //Опрашиваем оптопары ... Если рюмка поставлена , светодиод светится синим, нет ничего - не светится
        for (int i = 0; i < max_DrinkCount; i++) {

            int val = analogRead(Optics[i]);     // считываем значение
//        Serial.println(val);
            if (val < Optics_porog[i]) {
                strip.setPixelColor(i, strip.Color(0, 0, 0));
            } else {
                strip.setPixelColor(i, strip.Color(0, 0, 255));
            }
            //    delay(20);

        }
        strip.show();
        Batery();
        ledTime = currentTime;
    }
    //encoder_sw_prew = encoder_sw;
    //loopTime = currentTime;

    //}
}
