# AgendaSim

 Simulación de un sistema de agendamiento de múltiples citas consecutivas para un hospital. Este es el código utilizado en el proyecto de graduación:

"Aplicación de la simulación de eventos discretos para la mejora en la 
organización de los recursos de atención en la especialidad de prostodoncia 
del departamento de odontología de un hospital público de Costa Rica"

Sustentantes:
- Juan José Álvarez Pacheco
- Carlos Daniel Martínez Sánchez
- María Alejandra Solís Rojas

Para optar por el grado de licenciatura en Ingeniería Industrial de la Universidad de Costa Rica.

## Descripción General

El proceso consiste en una serie de 6 citas de secuencia múltiple en donde el paciente es revisado con un doctor durante un espacio de tiempo definido. Al terminar una cita inmediatamente después se le es agendada la fecha de la siguiente cita (el tiempo mínimo es una semana después). La razón es que el laboratorio de prótesis debe producir el insumo que se entregará en la siguiente cita. 

![C_Proceso](https://github.com/Tricipy/AgendaSim/assets/75949039/5146a23c-3fc1-4790-a42f-d9c37f471c14)

La cita de Control es una excepción ya que el tiempo mínimo entre la Entrega de la prótesis y la cita de control es de 2 semanas.

El proceso cuenta con 6 doctores. Cada uno tiene un horario definido. Los doctores trabajan de Lunes a Viernes durante una cierta cantidad de horas cada día. Cada doctor da todos los tipos de citas. Una vez el paciente lleva la cita de Impresión con un doctor específico entonces debe de completar todo el proceso con este mismo doctor.

## Funcionamiento
A nivel general, la aplicación está compuesta de una interfaz, código en R para correr la simulación, y código de Rmarkdown para generar un HTML de salida resumiendo los resultados obtenidos.

![C_RelaciónArchivos](https://github.com/Tricipy/AgendaSim/assets/75949039/4b1d7a64-6f22-458c-a602-42c8b8aa6d53)

A grandes rasgos la lógica de la simulación consiste en ingresar los horarios de los doctores como un Input y convertirlos en una **Agenda Global** esta Agenda es una tabla en donde cada fila consiste en una cita con las siguientes características:
- Momento exacto de la cita (fecha, hora, día de la semana, tiempo de simulación...)
- Id del doctor con el que se va a recibir la cita
- Tipo de cita (Cupo Nuevo, Impresión, Rodetes, etc)

Esta Agenda Global se construye utilizando el paquete de dplyr, juntando los horarios de los doctores, replicándolos una cantidad de veces igual a la cantidad de semanas que se desea simular.

El comportamiento que se desea lograr es el siguiente. Colocar una cierta cantidad de cupos de tipo de cita es el quivalente a asignar una capacidad de producción a cada uno de los procesos de una cita. Junto a ello, se prueba el comportamiento del sistema con parámetros de entrada como la tasa de entrada, y probabilidades de rechazo, ausentismo y abandono.

 ![L2](https://github.com/Tricipy/AgendaSim/assets/75949039/f6e73b7c-5b52-4b31-a885-1b49a00b7f6f)

Finalmente se corre la simulación durante un periodo, como por ejemplo durante un año y se extraen los resultados de desempeño del sistema. Esto permite principalmente entender cuanto tiempo están durando las personas en cada cola y entender áreas en donde mejorar el cuello de botella.

![L3](https://github.com/Tricipy/AgendaSim/assets/75949039/1f77f695-7006-4946-a9ca-dd1cc229b759)

### Input

Estos se encuentran en la carpeta de Input y consisten en una serie de 4 Exceles en donde está registrado en un formato específico:
- Los parámetros de entrada del proceso. Aquí se incluyen fechas de inicio y final de la simulación, probabilidades de ausentismo, abandono, reproceso y rechazo. Y adicionalmente opciones de configuración relativas a si se desea que haya un cambio de horarios de doctores en medio de la simulación, y si se desea que el sistema empiece sin pacientes internamente o si se prefiere que empiece con una cantidad de cola equivalente a fechas específicas dadas.
- Los horarios de los doctores Para cada doctor hay un horario específico semanal. Este es el Input principal utilizado para construir la Agenda Global.
- En caso de desearse un cambio de horario en un punto dado de la simulación, los horarios nuevos que se utilizarían para cada doctor. Es decir, a partir de una cierta fecha los horarios de los doctores cambian. Permite agregar o reducir la capacidad del proceso en un momento dado.
- Si se desea que el proceso inicie con una cantidad de pacientes ya en el sistema para cada tipo de cita entonces el archivo de "MaxFechas" agrega pacientes para llenar las colas hasta una fecha dada. Por ejemplo, si hay 3 meses de cola para la cita de Impresión entonces se analiza cuantos cupos disponibles hay en 3 meses y antes de que inicie la simulación se inyecta esta cantidad de pacientes al sistema.

![Input1](https://github.com/Tricipy/AgendaSim/assets/75949039/d143e991-115a-44c3-af16-bee359bd4c97)

### Simulación en R: AgSim

La base para esta sección corresponde a la librería de R Simmer (https://r-simmer.org/) que junto a Tidyverse (https://www.tidyverse.org/) permiten que el proyecto sea posible.

R Simmer ofrece el framework de simulación de eventos discretos. A través de sus funciones es posible crear un "enviroment" en donde se crean pacientes y son atendidos por recursos (doctores). Los pacientes siguen una trayectoria a través del sistema de citas múltiples, teniendo la posibilidad de ausentarse y abandonar el proceso. La última cita de Control también ofrece la posibilidad de reproceso.

R Simmer se queda ligeramente corto en dos funcionalidades necesarias para este proyecto: 
- Fue necesario mapear el tiempo de simulación a un horario real ya que R Simmer tan solo ofrece la posibilidad de ver "unidades de tiempo". Fue necesario entender el comportamiento a nivel de días, semanas, horas, minutos para poder replicar los horarios de los doctores.
- R Simmer no ofrecía una funcionalidad de agendamiento de citas. La librería esta adaptada a procesos en los cuáles apenas un recurso se desocupa, el siguiente elemento en la cola lo toma. Para el sistema de agendamiento se requiere precisamente la posibilidad de agendar citas en un momento específico de un día específico luego de consultar si ese campo se encuentra desocupado. Para ello es la construcción de la **Agenda Global**.

A nivel de código, cada vez que un paciente ingresa al proceso o bien solicita una cita, se debe fijar en la Agenda Global en donde se encuentran todos los cupos. Se busca el cupo disponible más cercano posterior al tiempo mínimo entre citas (una semana) y en caso de encontrarse desocupado se reserva dicho campo. Si otro paciente está buscando una cita con el mismo doctor y mismo tipo de cita entonces verá en la Agenda Global que ese cupo está ocupado y pasará al siguiente más cercano. De esta manera intentar aproximarse al comportamiento del sistema real.


**Diagramas de Trayectoria**

Para la cita de Valoración/Cupo Nuevo el proceso es el siguiente. Se asigna siempre el doctor con cupo disponible más cercano:
![D_Programación](https://github.com/Tricipy/AgendaSim/assets/75949039/6faa8ebe-cbf1-423f-a78d-7755f028ed96)

Luego de asignarse a un doctor en específico, las citas siguen el siguiente patrón:
![D_Programación2](https://github.com/Tricipy/AgendaSim/assets/75949039/7891a98d-65c5-4371-8bb4-d87f027c688d)

Continuando con el diagrama, observesé que  para tipo de cita y cada tipo de doctor se tiene el mismo proceso de asignación, espera, ausentismo y recepción de la cita.
![D_Programación3](https://github.com/Tricipy/AgendaSim/assets/75949039/2d9c83c8-6ab6-4653-adbb-a6022e4a6639)

El resultado final del script de AgSim es un Excel que contiene a la Agenda Global. Esta describe cada movimiento ocurrido en la simulación ya que observando los cupos es posible saber en que momento que paciente recibió qué tipo de cita con cuál doctor. Esta agenda también incluye si el paciente se ausentó, si abandonó el proceso, si fue rechazado en la cita de Cupo Nuevo etc.

### Generador de Output: Reporte-Metricas-Sim.Rmd

Con el anterior Output es posible construir un Reporte, tipo Dashboard mostrando los resultados de la corrida de simulación


### La interfaz: SimIntXL.xlsm

## Instalación 

## Cita del Proyecto de Graduación
