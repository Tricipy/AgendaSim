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

### Simulación en R: AgSim

### Generador de Output: Reporte-Metricas-Sim.Rmd

### La interfaz: SimIntXL.xlsm

## Instalación 

## Cita del Proyecto de Graduación
