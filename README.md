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

Si se desea consultar el trabajo escrito el link se encuentra en la siguiente ubicación:
https://repositorio.sibdi.ucr.ac.cr/items/14da3281-6d48-402f-9655-66e9996cd3fa/full

## 1. Descripción General

El proceso consiste en una serie de 6 citas de secuencia múltiple en donde el paciente es revisado con un doctor durante un espacio de tiempo definido. Al terminar una cita inmediatamente después se le es agendada la fecha de la siguiente cita (el tiempo mínimo es una semana después). La razón es que el laboratorio de prótesis debe producir el insumo que se entregará en la siguiente cita. 

![C_Proceso](https://github.com/Tricipy/AgendaSim/assets/75949039/5146a23c-3fc1-4790-a42f-d9c37f471c14)

La cita de Control es una excepción ya que el tiempo mínimo entre la Entrega de la prótesis y la cita de control es de 2 semanas.

El proceso cuenta con 6 doctores. Cada uno tiene un horario definido. Los doctores trabajan de Lunes a Viernes durante una cierta cantidad de horas cada día. Cada doctor da todos los tipos de citas. Una vez el paciente lleva la cita de Impresión con un doctor específico entonces debe de completar todo el proceso con este mismo doctor.

## 2. Funcionamiento
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

### 2.1 Input

Estos se encuentran en la carpeta de Input y consisten en una serie de 4 Exceles en donde está registrado en un formato específico:
- Los parámetros de entrada del proceso. Aquí se incluyen fechas de inicio y final de la simulación, probabilidades de ausentismo, abandono, reproceso y rechazo. Y adicionalmente opciones de configuración relativas a si se desea que haya un cambio de horarios de doctores en medio de la simulación, y si se desea que el sistema empiece sin pacientes internamente o si se prefiere que empiece con una cantidad de cola equivalente a fechas específicas dadas.
- Los horarios de los doctores Para cada doctor hay un horario específico semanal. Este es el Input principal utilizado para construir la Agenda Global.
- En caso de desearse un cambio de horario en un punto dado de la simulación, los horarios nuevos que se utilizarían para cada doctor. Es decir, a partir de una cierta fecha los horarios de los doctores cambian. Permite agregar o reducir la capacidad del proceso en un momento dado.
- Si se desea que el proceso inicie con una cantidad de pacientes ya en el sistema para cada tipo de cita entonces el archivo de "MaxFechas" agrega pacientes para llenar las colas hasta una fecha dada. Por ejemplo, si hay 3 meses de cola para la cita de Impresión entonces se analiza cuantos cupos disponibles hay en 3 meses y antes de que inicie la simulación se inyecta esta cantidad de pacientes al sistema.

![Input1](https://github.com/Tricipy/AgendaSim/assets/75949039/d143e991-115a-44c3-af16-bee359bd4c97)

### 2.2 Simulación en R: AgSim

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

### 2.3 Generador de Output: Reporte-Metricas-Sim.Rmd

Con el anterior Output es posible construir un Reporte, tipo Dashboard mostrando los resultados de la corrida de simulación. El enfoque principal está en entender la eficiencia del proceso

Se puede analizar la cantidad de citas realizadas para cada Doctor:
![MarkDown1](https://github.com/Tricipy/AgendaSim/assets/75949039/b08a6bea-b1a1-4372-871c-08dff752fb14)

Se puede entender la cantidad de cupos disponibles no utilizados, una medida de que tan eficiente es el proceso y la alocación de recursos:
![MarkDown2](https://github.com/Tricipy/AgendaSim/assets/75949039/a6711173-6804-4c85-bc52-d035c71c056b)

El siguiente gráfico responde a la pregunta si yo solicito una cita de X tipo con el doctor Y en una fecha dada, ¿en qué fecha la voy a recibir?
![Markdown3](https://github.com/Tricipy/AgendaSim/assets/75949039/73fc0523-8c46-42f3-9622-ec2091727cdf)

Obtener la diferencia entre ambas fechas del gráfico anterior nos da el tiempo de espera para cada fecha de solicitud.
![Markdown4](https://github.com/Tricipy/AgendaSim/assets/75949039/afb8463a-65e6-4413-b0bd-f5d9060861d1)

También la anterior medida nos permite entender cuál es la cantidad de pacientes en la cola para cada momento de la simulación:
![Markdown5](https://github.com/Tricipy/AgendaSim/assets/75949039/2b528a3c-599b-4646-9e87-327fd8d3213e)

Naturalmente cambiar los parámetros de la simulación resulta en gráficos considerablemente distintos. El propósito de la herramienta al final del día es entender que cambios pueden ayudar a reducir las colas.

### 2.4 La interfaz: SimIntXL.xlsm

La interfaz permite al usuario manipular los parámetros de entrada y sin que sea necesario manipular el código de AgendaSim.R ni correr el archivo de Rmarkdown. Para construirla se utilizan macros de Excel. Esta interfaz ofrece las siguientes vistas.

Un menú principal en donde se accede a las distintas configuraciones y además permiter ejecutar los archivos de R.
![Interfaz1](https://github.com/Tricipy/AgendaSim/assets/75949039/f728d68b-9d4b-4a78-87df-835c9bcc274c)

La parametrización de la simulación en función de fechas de inicio y final, tasas de llegada, probabilidad de ausentismo etc.
![Interfaz2](https://github.com/Tricipy/AgendaSim/assets/75949039/ccfda5c5-7eff-4629-81f0-3e25d1d48bee)

La posibilidad de configurar los horarios de los doctores dentro de la misma interfaz. Agregando y quitando cupos para los distintos tipos de citas.
![Interfaz3](https://github.com/Tricipy/AgendaSim/assets/75949039/11204fd6-bde4-4482-b237-6eab29a8f48a)

Una vista que permite entender cuál es la capacidad configurada (por doctor y tipo de cita) que actualmente se le está dando al sistema.
![Interfaz4](https://github.com/Tricipy/AgendaSim/assets/75949039/c99d585b-cdb3-482c-ba0c-b4f9a088ccb2)

De esta manera el usuario es capaz de configurar la aplicación y recibir el output sin tener que correr el código, todo desde Excel.

## 3. Instalación 

En el manual de usuario se muestra de manera detallada el proceso de instalación. Sin embargo hay dos pasos vitales y son relativos a colocar los directorios de donde se encuentran los archivos. 

En primer lugar se debe colocar la ruta del directorio dentro de AgSim.R correspondiente a donde se encuentra el mismo:
![image](https://github.com/Tricipy/AgendaSim/assets/75949039/46ecf29f-e256-4efb-aefa-d6895b7cee8f)

En segundo lugar, en la interfaz en la hoja de Configuración de la Interfaz, se debe colocar las rutas a los archivos de Excel así como al proyecto de R y la ruta a la aplicación de R
![image](https://github.com/Tricipy/AgendaSim/assets/75949039/de2ca6f7-f643-4fd8-a1ce-c6ed22a9e09a)

Con esto, la aplicación debería encontrarse lista para funcionar.

## 4. Bibliografía


Nuestro proyecto de graduación tiene la siguiente referencia:

Álvarez, J. J., Martínez, C. D., & Solís, M. A. (2024). Aplicación de la simulación de eventos discretos para la mejora en la organización de los recursos de atención en la especialidad de prostodoncia del departamento de odontología de un hospital público de Costa Rica. San José, San José, Costa Rica: Universidad de Costa Rica.

Adicionalmente, por ser dos paquetes esenciales en el código utilizado se incluye la referencia a Tidyverse y a R Simmer:

Ucar I, Smeets B, Azcorra A (2019). “simmer: Discrete-Event Simulation for R.” Journal of Statistical Software, 90(2), 1–30. doi:10.18637/jss.v090.i02.

Wickham, H., Çetinkaya-Rundel, M., & Grolemund, G. (2023). R for data science (2nd edition). 
O’Reilly Media, Inc.
