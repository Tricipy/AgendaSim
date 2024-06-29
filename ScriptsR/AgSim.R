# Simulacion_Citas_Multiples
## Proyecto de Graduacion
### Juan Jose alvarez Pacheco B80412
### Maria Alejandra Solis
### Carlos Daniel

s_ruta_dir = "C:/Users/XPC/Documents/Code/GitHub/AgendaSim"
s_guardar = TRUE
s_renderizar = TRUE

simulacion_AgSim = function(ruta ,render, guardar){

cronometro_inicio = Sys.time()  

#_______________________________________________________________________________
# Carga de Librerias
#_______________________________________________________________________________

if(!require("here")) install.packages("here"); library("here")
if(!require("readxl")) install.packages("readxl"); library("readxl")
if(!require("simmer")) install.packages("simmer"); library("simmer")
if(!require("tidyverse")) install.packages("tidyverse"); library("tidyverse")
if(!require("lubridate")) install.packages("lubridate"); library("lubridate")
if(!require("openxlsx")) install.packages("openxlsx"); library("openxlsx")

setwd(ruta)
here::i_am("ScriptsR/AgSim.R")


#_______________________________________________________________________________
# Settings
#_______________________________________________________________________________

df_settings = read_xlsx(here("Input", "Descripcion_Proceso.xlsx"), 
                        sheet = "Settings")

inicio_vacio = as.logical(df_settings[[which(df_settings$Setting == "inicio_vacio"),2]])
cambio_de_horario = as.logical(df_settings[[which(df_settings$Setting == "cambio_de_horario"),2]])
#s_ausentismo_por_hora = as.logical(df_settings[[which(df_settings$Setting == "s_ausentismo_por_hora"),2]])
s_ausentismo_por_hora = FALSE
s_ausentismo_por_tipo_cita = as.logical(df_settings[[which(df_settings$Setting == "s_ausentismo_por_tipo_cita"),2]])
#guardar = as.logical(df_settings[[which(df_settings$Setting == "guardar"),2]])
nombre_archivo_guardado = df_settings[[which(df_settings$Setting == "nombre_archivo_guardado"),2]]
renderizar = render

#_______________________________________________________________________________
# Parametros
#_______________________________________________________________________________
### Descripcion del proceso ###

tasa_llegadas_base = as.numeric(df_settings[[which(df_settings$Setting == "tasa_llegadas_base"),2]])/(7*24*60)

df_descripcion_proceso = read_xlsx(here("Input", "Descripcion_Proceso.xlsx"), 
                                   sheet = "Proceso")


if(!(s_ausentismo_por_tipo_cita || s_ausentismo_por_hora)){
  df_descripcion_proceso$probabilidad_ausentismo = 0
}

df_descripcion_proceso = df_descripcion_proceso %>% arrange(orden_citas)
df_descripcion_proceso$tiempo_minimo_entre_citas = as.difftime(df_descripcion_proceso$tiempo_minimo_entre_citas, units = "days")

### Fecha Inicio de Simulacion ###
#El Inicio y el Final deben ser Lunes y Domingo respectivamente.

fecha_inicio_simulacion = df_settings[[which(df_settings$Setting == "fecha_inicio_simulacion"),2]] %>% as_date()
fecha_cambio_horario = df_settings[[which(df_settings$Setting == "fecha_cambio_horario"),2]] %>% as_date()
fecha_final_simulacion = df_settings[[which(df_settings$Setting == "fecha_final_simulacion"),2]] %>% as_date()
fecha_final_agenda = df_settings[[which(df_settings$Setting == "fecha_final_agenda"),2]] %>% as_date()

#Para evitar bug confuso la fecha_final_agenda tiene que ser una semana superior a la fecha_final_simulacion

if(fecha_final_simulacion == fecha_final_agenda) {
  fecha_final_agenda = fecha_final_agenda + 7
}


### Probabilidad de abandono dado ausentismo ###

p_abandono_aus = df_settings[[which(df_settings$Setting == "p_abandono_aus"),2]] %>% as.numeric()
if(!(s_ausentismo_por_tipo_cita || s_ausentismo_por_hora)){
  p_abandono_aus = 0
}

### Probabilidad de reproceso en control ###

p_reproceso_control = df_settings[[which(df_settings$Setting == "p_reproceso_control"),2]] %>% as.numeric()
df_descripcion_proceso = df_descripcion_proceso %>% cbind(tibble("probabilidad_reproceso" = c(0,0,0,0,0,p_reproceso_control)))

### Probabilidad de rechazo en cupo nuevo ###

p_rechazo_cuponuevo = df_settings[[which(df_settings$Setting == "p_rechazo_cuponuevo"),2]] %>% as.numeric()

### Tiempo de Corrida ###

tiempo_de_corrida = difftime(fecha_final_simulacion, fecha_inicio_simulacion, units = "mins")


### Matriz de Ausentismos ###

if(s_ausentismo_por_hora){
  print(1)
  mat_ausentismos = read_xlsx(here("Input", "Matriz_Ausentismos.xlsx")) %>% as.matrix()
  mat_ausentismos = mat_ausentismos[,-1]
  rownames(mat_ausentismos) = seq(0,23,1)
} else {
  
  mat_ausentismo = c()
  
}



df_maxfechas = read_xlsx(here("Input", "MaxFechas.xlsx"))

#_______________________________________________________________________________
# Funcion para guardar el archivo final
#_______________________________________________________________________________

f_guardar_varias_replicas = function(nombre_archivo_guardado, ag_workbook, contador = 0)
{
  if (file.exists(here("Output", paste0(nombre_archivo_guardado ,".xlsx")))){
    contador = contador + 1
    if(contador == 1){
      nombre_archivo_guardado = paste0(nombre_archivo_guardado,"_R",contador)
    } else {
      nombre_archivo_guardado = paste0(str_sub(nombre_archivo_guardado, 1, -4),"_R",contador) 
    }
    
    f_guardar_varias_replicas(nombre_archivo_guardado, ag_workbook, contador)  
    
  } else {
    ag_workbook %>% openxlsx::saveWorkbook(
      file = here("Output", paste0(nombre_archivo_guardado ,".xlsx")),
      overwrite = TRUE)
  }
  return(nombre_archivo_guardado)
} 

#_______________________________________________________________________________
# Funciones utilizadas para crear la agenda
#_______________________________________________________________________________

f_crear_horario_min_semana = function(horario){
  #
  res = horario %>% 
    pivot_longer(cols = horario %>% names() %>% .[3:length(horario)]) %>% 
    mutate(Dia_Sem = case_when(name == "Lunes" ~ 1,
                               name == "Martes" ~ 2,
                               name == "Miercoles" ~ 3, 
                               name == "Jueves" ~ 4, 
                               name == "Viernes" ~ 5, 
                               name == "Sabado" ~ 6, 
                               name == "Domingo" ~ 7),
           min_semana = Hora + (Dia_Sem-1) * (60 * 24)) %>% 
    arrange(min_semana)
  
  return(res)
}

f_leer_archivo = function(nombre_archivo) {
  
  #Se define el formato de los horarios
  
  horas = seq(from = 0, to = (24*60) - 1, by=5) 
  horas_difftime = as.difftime(horas, units = "mins")
  
  horario_formato = tibble("Hora" = horas_difftime, 
                           "Lunes" = NA, 
                           "Martes" = NA, 
                           "Miercoles" = NA, 
                           "Jueves" = NA, 
                           "Viernes" = NA,
                           "Sabado" = NA,
                           "Domingo" = NA)
  
  
  #Este horario nos va a permitir almacenar luego los horarios de los doctores.
  #Ademas es nuestra entrada por decirlo de alguna manera
  horario_formato = horario_formato %>% 
    mutate("HMS" = hms::as_hms(Hora)) %>% 
    select(HMS, Hora, everything())
  
  #El horario de un doctor es tomar el horario base y modificarlo para que incluya
  #los tipos de citas considerados en el proceso.
  #Por conveniencia vamos a hacer que este se pueda subir a partir de un excel.
  
  hojas = excel_sheets(nombre_archivo)
  df_lista = lapply(hojas, function(i){read_xlsx(nombre_archivo, sheet = i)})
  names(df_lista) = hojas
  
  for (name in names(df_lista)) {
    df_lista[[name]]$HMS = horario_formato$HMS
    df_lista[[name]]$Hora = horario_formato$Hora
  }
  
  df_lista = lapply(df_lista, function(i){f_crear_horario_min_semana(i)})
  
  return(df_lista)
}

f_horarios_a_excel = function(horario){
  
  #Esta funcion se usa a la hora de guardar los resultados y tiene por objetivo
  #a partir del horario_actual crear una tabla que pueda utilizarse para saber
  #como quedaron esos horarios.
  
  df_horario = horario[["Doc1"]] %>% mutate("Doc" = names(horario)[1]) %>% head(0)
  
  for (doc in names(horario)){
    df_horario = rbind(df_horario, horario[[doc]] %>% mutate("Doc" = doc))
  }
  df_horario = df_horario %>% select(Doc, everything())
  
  df_horario
  
  return(df_horario)
}



f_crear_agenda_continua = function(horario_min_semana,
                                   id_doc,
                                   fecha_i_LUNES,
                                   fecha_f_DOMINGO, 
                                   df_descripcion_p = df_descripcion_proceso){
  
  fecha_i_LUNES = fecha_i_LUNES %>% as.POSIXct()
  fecha_f_DOMINGO = fecha_f_DOMINGO %>% as.POSIXct()
  
  hour(fecha_i_LUNES) = 0
  minute(fecha_i_LUNES) = 0
  second(fecha_i_LUNES) = 0
  
  hour(fecha_f_DOMINGO) = 23
  minute(fecha_f_DOMINGO) = 55
  second(fecha_f_DOMINGO) = 0
  
  fecha = seq.POSIXt(fecha_i_LUNES, fecha_f_DOMINGO, by = 5*60 ) #5*60 para 5 minutos
  
  #Se revisa que la fecha inicial sea lunes
  #Se revisa que la fecha final sea domingo
  cond1 = weekdays.POSIXt(fecha_i_LUNES) == "Monday" || weekdays.POSIXt(fecha_i_LUNES) == "lunes"
  cond2 = weekdays.POSIXt(fecha_f_DOMINGO) == "Sunday" || weekdays.POSIXt(fecha_f_DOMINGO) == "domingo"
  
  if (cond1 && cond2) {
    cantidad_semanas = difftime(fecha_f_DOMINGO, fecha_i_LUNES, units = "weeks") %>% round()
  } else {
    print("No se utilizaron fechas LUNES y DOMINGO para inicio de simulacion")
  }
  
  #Esta lista continua asume que los periodos de vigencia de las agendas
  #deben empezar un lunes siempre, y terminar un domingo, siempre
  #Por esta razon, el tiempo de inicio y el tiempo final que van en formato de 
  #fecha, se verifica SIEMPRE que correspondan a un lunes y a un domingo,
  #respectivamente
  
  df_para_repetir = horario_min_semana %>% 
    select(min_semana, 
           min_hora_dia = Hora, 
           nombre_dia_sem = name, 
           num_dia_sem = Dia_Sem, 
           campo_cita = value) %>% 
    mutate(campo_tomado = FALSE,
           id_paciente = NA)
  
  df_agenda_vacia =  df_para_repetir %>% 
    slice(rep(1:(n()),cantidad_semanas)) %>% 
    mutate(fecha = fecha,
           tiempo_sim = (row_number()-1) * 5) %>% 
    select(fecha, tiempo_sim, nombre_dia_sem, campo_cita, campo_tomado, id_paciente) %>% filter(!is.na(campo_cita))
  
  df_tiempos_procedimientos = df_descripcion_p %>% 
    select(tipos_citas, tiempos_procedimientos) %>% 
    rename(campo_cita = tipos_citas)
  
  df_agenda_vacia = df_agenda_vacia %>% 
    left_join(df_tiempos_procedimientos, 
              by = "campo_cita") %>%
    group_by(campo_cita) %>% 
    mutate(es_cita_inicial = ifelse((row_number()-1) %% (tiempos_procedimientos/5) == 0, TRUE, FALSE))
  
  df_agenda_vacia = df_agenda_vacia %>% filter(es_cita_inicial) %>% select(-tiempos_procedimientos, -es_cita_inicial)
  
  df_agenda_vacia = df_agenda_vacia %>% mutate(id_doc = id_doc) %>% 
    select(fecha, tiempo_sim, nombre_dia_sem, id_doc, campo_cita, campo_tomado, id_paciente) %>% 
    ungroup()
  
  return(df_agenda_vacia)
}

f_crear_agenda_global= function(lista_horarios_min_semana, 
                                fecha_i_LUNES_,
                                fecha_f_DOMINGO_) {
  #Esta funcion agrupa todos los horarios y repite
  #f_crear_agenda_continua para cada uno de los doctores
  #Para llegar a tener una agenda global con todas las citas
  
  for (i in 1:length(lista_horarios_min_semana)){
    a = f_crear_agenda_continua(
      horario_min_semana = lista_horarios_min_semana[[i]],
      id_doc = paste0("doc",i),
      fecha_i_LUNES = fecha_i_LUNES_,
      fecha_f_DOMINGO = fecha_f_DOMINGO_)
    
    
    if(!exists("agenda_continua")){
      agenda_continua = a
    } else {
      agenda_continua = agenda_continua %>% rbind(a)
    }
  }
  
  agenda_continua = agenda_continua %>% arrange(tiempo_sim, id_doc, campo_cita)
  
  
  return(agenda_continua)
  
}   

## Funciones para crear los doctores en la simulacion
f_crear_agenda_capacidad = function(horario_min_semana, tipo_cita){
  #Esta funcion crea un objeto de schedule dentro de simmer que determina la
  #capacidad de cada uno de los recursos (que corresponden a los doctores)
  horario_min_semana = horario_min_semana %>%
    filter(value == tipo_cita) %>%
    select(min_semana) %>%
    arrange(min_semana)
  horario_min_semana$min_semana = as.double(horario_min_semana$min_semana)
  para_tt = horario_min_semana %>%
    mutate(tt_lead = lead(min_semana),
           diferencia = tt_lead - min_semana,
           diferencia = ifelse(is.na(diferencia), 5, diferencia))
  para_tt = para_tt %>% mutate(min_semana_mas_5 = min_semana + 5) %>%
    select(min_semana, min_semana_mas_5, diferencia)
  tabla_capacidad = para_tt %>%
    mutate(horas_reales = case_when(diferencia == 5 ~ min_semana,
                                    diferencia != 5 ~ min_semana_mas_5)) %>%
    select(horas_reales, diferencia)
  tabla_capacidad = tabla_capacidad %>%
    rbind(tibble(horas_reales = max(tabla_capacidad$horas_reales)+5, diferencia = 0))
  tabla_capacidad = rbind(tibble(horas_reales = 0, diferencia = 0), tabla_capacidad)
  tabla_capacidad = tabla_capacidad %>% mutate(capacidad = ifelse(diferencia == 5, 1,0))
  schedule(timetable = tabla_capacidad$horas_reales,
           values = tabla_capacidad$capacidad,
           period = 24*60*7) %>%
    return()
}

f_crear_recursos = function(
  .env,
  df_descripcion_proceso = df_descripcion_proceso,
  cantidad_doctores,
  lista_horarios_min_semana) {
  # Ingresos
  #.env : se refiere al enviroment del modelo
  #df_descrpcion_proceso : tibble con el mismo nombre
  #cantidad_doctores : La cantidad de doctores
  #lista_horarios : Es una lista con una cantidad de tibbles de con formato
  # horario_formato. Debe coincidir con la cantidad de doctores.
  # Descripcion
  # Esta funcion crea recursos con un horario semanal correspondiente al de la
  # lista_horarios para cada uno de los doctores en formato min_semana.
  # La cantidad de recursos creados
  # corresponde a cantidad_doctores x tipos_citas
  for (doc in 1:(cantidad_doctores)){
    for (tipo_cita in df_descripcion_proceso$tipos_citas){
      
      
      #agenda_capacidad = f_crear_agenda_capacidad(lista_horarios_min_semana[[doc]], tipo_cita)
      
      
      .env %>% add_resource(
        name = paste0("doc",doc,"_",tipo_cita))#,
      #capacity = agenda_capacidad) #Se utiliza la funcion anterior para crear el timetable
    }
  }
}

f_generar_pacientes = function(tasa_llegadas,
                               agenda_gl = agenda_global,
                               agenda_gl_ba = agenda_global_base,
                               df_desc = df_descripcion_proceso){
  # Se revisa la agenda global, por el proceso de "Cupo Nuevo"
  # Si ya se llego al limite del tiempo de la simulacion, se dejan de generar
  # nuevos pacientes (ya que estos serian asignados hasta despues)
  #Revisa agenda global
  cond = agenda_gl %>%
    filter(campo_cita == df_descripcion_proceso$tipos_citas[1]) %>%
    tail(1) %>%
    .$campo_tomado
  if(cond){
    return(Inf)
  } else {
    return(tasa_llegadas)
  }
}



#_______________________________________________________________________________
# Funciones utilizadas durante la simulacion en orden de eventos
#_______________________________________________________________________________
f_asignar_id_paciente = function(){
  ## Se le asigna un id al paciente al entrar en el proceso
  ## Afecta la variable global contador_pacientes_id
  id = contador_pacientes_id
  contador_pacientes_id <<- contador_pacientes_id + 1
  return(id)
}

f_asignar_doc_a_paciente= function(t_i, agenda_gl = agenda_global, inicio_c=1){
  #Esta logica deberia considerar que tan pesada esta la agenda de cada
  #doctor al momento de inicio de la simulacion, asi como la capacidad
  #proyectada
  #Como se hace en el servicio actualmente? Seguro a la hora de asignar la cita
  #De valoracion, se le da al doctor que se encuentre disponible mas cercano
  
  
  #Notese que existe la posibilidad de cambiar esto con la variable de inicio_c
  #Esta variable permite cambiar en cual longitud de cita nos fijamos para 
  #asignar al doctor. Tal vez lo mejor es asignarlo basado en las citas de 
  #Impresion?
  
  if(inicio_c == 1){
    t_minimo_entre_citas = 0
  } else {
    t_minimo_entre_citas = df_descripcion_proceso$tiempo_minimo_entre_citas[inicio_c]
  }
  t_minimo_entre_citas = as.numeric(t_minimo_entre_citas) * 24*60
  
  
  doc_asignado = agenda_gl %>%
    filter(campo_cita == df_descripcion_proceso$tipos_citas[inicio_c],
           !campo_tomado,
           tiempo_sim >= t_i + t_minimo_entre_citas) %>%
    
    arrange(tiempo_sim) %>% 
    
    head(1) %>% .$id_doc
  
  return(doc_asignado %>% parse_number())
  
}

f_registrar_t_inicio = function(id_p, t_sim, id_doctor){
  ## Se registra el tiempo de llegada de cada paciente en una matriz global
  mat_t_inicio<<-rbind(mat_t_inicio, c(id_p, t_sim, id_doctor))
  return(t_sim)
}

f_asignar_fecha_cita = function(
  id_p,
  id_doctor,
  tipo_cita,
  t_sim_ahora,
  agenda = agenda_global,
  df_descripcion_p = df_descripcion_proceso,
  t_min_entre_citas){
  
  
  #### PARA hacer Ajustess
  # id_p = 5
  # id_doctor = 1
  # tipo_cita = 1
  # t_sim_ahora = 0
  # agenda = agenda_global
  # df_descripcion_p = df_descripcion_proceso
  #####
  
  id_doctor = paste0("doc",id_doctor)
  tipo_cita = df_descripcion_p$tipos_citas[tipo_cita]
  #Para establecer el tiempo_minimo_entre_citas
  
  if(t_min_entre_citas){
    tiempo_minimo_entre_citas = df_descripcion_proceso %>%
      filter(tipos_citas == tipo_cita) %>% .$tiempo_minimo_entre_citas
    units(tiempo_minimo_entre_citas) = "mins"
    tiempo_minimo_entre_citas = tiempo_minimo_entre_citas %>% as.numeric()
  } else {
    tiempo_minimo_entre_citas = 0
  }
  
  # Aqui va la logica de como el paciente agarra la agenda
  # En este caso vamos a agarrar la primera cita que se encuentre disponible
  # en el sistema, que ademas cumpla con la cantidad de dias minimos entre cita
  # y cita (tiempo_minimo_entre_citas)
  
  df_asignacion_agenda = agenda %>%
    filter(id_doc == id_doctor,
           campo_cita == tipo_cita,
           campo_tomado == FALSE,
           tiempo_sim >= t_sim_ahora + tiempo_minimo_entre_citas) %>%
    head(1) %>% #AGARRAMOS LA PRIMERA CITA DISPONIBLE
    mutate(campo_tomado = TRUE,
           id_paciente = id_p)
  if(nrow(df_asignacion_agenda) == 0) {
    return(-1) #Esto implica que no quedan campos en la agenda y por ende el
    #paciente debe de tomar otra ruta
    #Se usa cuando ya se estarian asignando gente a un nuevo horario a muy futuro
    #Que por ende se sale del alcance de las fechas de la simulacion
    #Ademas como se detiene la simulacion entonces la agenda global no se actualiza.
  }
  # Version vieja ineficiente usando anti_join
  # agenda_modificada = df_asignacion_agenda %>%
  #   rbind(agenda %>%
  #           anti_join(df_asignacion_agenda, by = c("fecha", "id_doc", "campo_cita"))) %>%
  #   arrange(tiempo_sim, id_doc, campo_cita)
  
  agenda = agenda %>% mutate(
    campo_tomado = if_else(tiempo_sim == df_asignacion_agenda$tiempo_sim &
                             id_doc     == df_asignacion_agenda$id_doc &
                             campo_cita == df_asignacion_agenda$campo_cita,
                           TRUE,
                           campo_tomado),
    id_paciente = if_else(tiempo_sim == df_asignacion_agenda$tiempo_sim &
                            id_doc     == df_asignacion_agenda$id_doc &
                            campo_cita == df_asignacion_agenda$campo_cita,
                          df_asignacion_agenda$id_paciente,
                          id_paciente))
  #Deseamos devolver dos cosas con esta funcion:
  #1. Queremos la agenda modificada para que esta se actualice en el scope
  #   global
  agenda_global <<- agenda
  #2. Queremos el tiempo de la cita asignada
  return(df_asignacion_agenda$tiempo_sim[1])
}

trj_fuera_de_alcance_tiempo_final = function(.trj) {
  branch(
    .trj,
    option = function() {ifelse(get_attribute(modelo, "tiempo_espera") == -1, 1,0)},
    continue = c(F),
    trajectory("Sale del sistema: Limite del alcance de la simulacion") #%>%
    ###################################Debugging################################
    # log_(function() {
    #   paste0("Al", get_attribute(modelo, "id_paciente"),
    #          "Se asigna cita a un tiempo posterior a la fecha final.")})
    ############################################################################
  )
}

f_hora_dia = function(id_p = get_attribute(modelo, "id_paciente")){
  #Version vieja que no sirve:
  #___________________________________________
  #hora_dia = floor(((ahora+espera)%%1440)/60)
  #return(hora_dia)
  #____________________________________________
  f = agenda_global %>% filter(id_paciente == id_p) %>% tail(1) %>% .$fecha
  return(hour(f))
}

f_dia_sem = function(id_p = get_attribute(modelo, "id_paciente")){
  #Esta funcion se fija en el tiempo de simulacion de la cita y lo convierte
  #en un numero entre 0 y 6 donde 0 representa Lunes y 6 representa Domingo
  #Version vieja que no sirve:
  #___________________________________________
  #dia_sem = floor(((ahora+espera) %% 10080)/(60*24))
  #return(dia_sem)
  #____________________________________________
  f = agenda_global %>% filter(id_paciente == id_p) %>% tail(1) %>% .$nombre_dia_sem
  f = which(f == c("Lunes", "Martes", "Miercoles", "Jueves", "Viernes", "Sabado", "Domingo"))
  return(f)
}

trj_asignacion_cita = function(.trj, orden_cita = 1, t_min_entre_citas){
  cita_tag = as.character(orden_cita)
  
  
  ##############################################################################
  # log_(function() {paste0("Paciente ",
  #                         get_attribute(modelo, "id_paciente"),
  #                         " es asignado al doctor ",
  #                         get_attribute(modelo, "doc") )}) %>%
  ##############################################################################
  
  
  
  set_attribute(.trj, "tipo_cita",tag = cita_tag, function(){
    df_descripcion_proceso$orden_citas[orden_cita] %>% as.numeric()
  }) %>%
    #Asignacion de la cita
    set_attribute("tiempo_espera",
                  function() {f_asignar_fecha_cita(
                    id_p = get_attribute(modelo, "id_paciente"),
                    id_doctor = get_attribute(modelo, "id_doc"),
                    tipo_cita = get_attribute(modelo, "tipo_cita"),
                    t_sim_ahora = simmer::now(modelo),
                    t_min_entre_citas = t_min_entre_citas
                  )}) %>%
    #Registro hora del dia cita (se usa para ausentismo)
    set_attribute("hora_cita",
                  function(){
                    f_hora_dia()}) %>%
    #Registro dia de la semana cita (se usa para ausentismo)
    set_attribute("dia_sem_cita",
                  function(){
                    f_dia_sem()}) %>%
    #Si no quedan cupos disponibles se recurre a sacar del sistema
    #porque esta fuera del alcance del final de la simulacion
    trj_fuera_de_alcance_tiempo_final()
  ############################DEBUGGING#########################################
  # log_(function() {paste0("Paciente ",
  #                         get_attribute(modelo, "id_paciente"),
  #                         " espera hasta ",
  #                         get_attribute(modelo, "tiempo_espera"),
  #                         " por el tipo de cita ",
  #                         get_attribute(modelo, "tipo_cita"))}) %>%
  ##############################################################################
}

trj_espera = function(.trj){
  timeout(.trj,
          function(){
            get_attribute(modelo, "tiempo_espera") - simmer::now(modelo)})
}

f_ausentismo = function(
  orden_cit,
  s_aus_por_hora = s_ausentismo_por_hora,
  s_aus_por_tipo_cita = s_ausentismo_por_tipo_cita,
  p_abandono_dado_aus,
  hora_cita = get_attribute(modelo, "hora_cita"),
  dia_cita = get_attribute(modelo, "dia_sem_cita"),
  mat_aus = mat_ausentismos,
  id_pac = get_attribute(modelo, "id_paciente"),
  t_sim = simmer::now(modelo)){
  #Para Pruebas ###############################################################
  # t_sim = 1400
  # id_pac = 14
  # hora_cita = 10
  # dia_cita = "Martes"
  # p_abandono = 0.08
  #############################################################################
  if(s_aus_por_tipo_cita & s_aus_por_hora) {
    # Si es ambos entonces se realiza un promedio entre los dos datos
    prob = mean(mat_aus[hora_cita, dia_cita],
                df_descripcion_proceso$probabilidad_ausentismo[orden_cita] )
  } else if(s_aus_por_hora){
    prob = mat_aus[hora_cita, dia_cita]
  } else if(s_aus_por_tipo_cita){
    prob = df_descripcion_proceso$probabilidad_ausentismo[orden_cit]
  } else {
    prob = 0
  }
  
  if(is.na(prob)){prob = 0}
  if(prob > 1){prob = 1} else if (prob < 0) {prob = 0}
  #REGISTRO TESTING
  # vec_prob <<- c(vec_prob,prob)
  #BORRAR ESTO DESPUeS
  se_da_aus = rbinom(prob = prob, n = 1, size = 1)
  if(se_da_aus){
    se_da_aband = rbinom(1,1, prob = p_abandono_dado_aus)
  } else {
    se_da_aband = 0
  }
  #Estas dos situaciones se registran en una matriz que registra el tiempo actual
  #la fecha de la cita a la que se falto, el id_paciente y esto de si abandona
  #y de si no
  if(se_da_aus){
    mat_r_ausentismos <<- rbind(mat_r_ausentismos,
                                c(id_pac, t_sim, se_da_aus, se_da_aband))
  }
  #Esta funcion ademas, devuelve cada una de las rutas del Branch a seguir
  #Si devuelve 0 no hay ausentismo
  #Si devuelve 1 si hay ausentismo pero no abandono
  #Si devuelve 2 hay ausentismo y abandono
  if (!se_da_aus){
    s = 0
  } else if (!se_da_aband) {
    s = 1
  } else {
    s = 2
  }
  #BORRARRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
  # vec_conteo_prob <<- c(vec_conteo_prob, s)
  #BORRARRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
  #BORRAR ESTO PARA REGISTRO SAICO DE PACIENTES
  # vec_tiempo_sim <<- c(vec_tiempo_sim, t_sim)
  # vec_hora_cita <<- c(vec_hora_cita, hora_cita)
  # vec_dia_sem <<- c(vec_dia_sem, dia_cita)
  # vec_id_pac <<- c(vec_id_pac, id_pac)
  #BORARRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
  return(s)
}

trj_ausentismo = function(.trj,
                          orden_cita,
                          p_abandono_dado_ausentismo){
  branch(
    .trj,
    option = function() {
      f_ausentismo(orden_cit = orden_cita,
                   p_abandono_dado_aus = p_abandono_dado_ausentismo)},
    continue = c(F, F),
    trajectory("Ausentismo y reagendamiento") %>%
      log_("Se da un reagendamiento", level = 3) %>%
      #Nota: En caso de ausentismo hay una espera de 0 a 2 semanas para reagendar
      simmer::timeout(function() runif(1, min = 0, max = 20160)) %>%
      simmer::rollback(target = as.character(orden_cita)),
    trajectory("Abandono") %>%
      log_("Se da un abandono", level = 3)
  )
}


f_reproceso = function(orden_cit,
                       id_pac = get_attribute(modelo, "id_paciente"),
                       t_sim = simmer::now(modelo)){
  
  
  
  prob = df_descripcion_proceso$probabilidad_reproceso[orden_cit]
  
  if(is.na(prob)){prob = 0}
  if(prob > 1){prob = 1} else if (prob < 0) {prob = 0}
  
  
  se_da_reproceso = rbinom(1,1, prob = prob)
  
  mat_r_reproceso <<- rbind(mat_r_reproceso,
                            c(id_pac, t_sim, se_da_reproceso))
  
  return(se_da_reproceso)
  
}


trj_reproceso = function(.trj,
                         orden_cita){
  branch(
    .trj,
    
    option = function() {
      f_reproceso(orden_cit = orden_cita)},
    
    continue = c(F),
    
    trajectory("Reproceso") %>%
      log_("Se da un reproceso", level = 3) %>%
      #Nota: En caso de reproceso hay una espera de 0 a 1 semanas para reagendar ?
      #simmer::timeout(function() runif(1, min = 0, max = 10080)) %>%
      simmer::rollback(target = as.character(orden_cita))
  )
}

f_rechazo = function(p_rechazo = p_rechazo_cuponuevo,
                     id_pac = get_attribute(modelo, "id_paciente"),
                     t_sim = simmer::now(modelo)){
  
  
  prob = p_rechazo
  
  if(is.na(prob)){prob = 0}
  if(prob > 1){prob = 1} else if (prob < 0) {prob = 0}
  
  
  se_da_rechazo = rbinom(1,1, prob = prob)
  
  mat_r_rechazo <<- rbind(mat_r_rechazo,
                          c(id_pac, t_sim, se_da_rechazo))
  
  return(se_da_rechazo)
}


trj_rechazo = function(.trj, p_rech = p_rechazo_cuponuevo, orden_cit = 1){
  
  if(orden_cit == 1){
    branch(
      .trj,
      
      option = function() {
        f_rechazo(p_rechazo = p_rech)},
      
      continue = c(F),
      
      trajectory("Rechazo") %>%
        log_("Se da un rechazo", level = 3)
    ) %>% return()
  } else {
    
    return(.trj)
    
  }
}


trj_recibe_cita = function(.trj){
  simmer::select(.trj, function(){
    paste0("doc",get_attribute(modelo,"id_doc"),"_",
           df_descripcion_proceso %>%
             filter(orden_citas == get_attribute(modelo, "tipo_cita")) %>%
             .$tipos_citas)
  }) %>%
    seize_selected() %>%
    timeout(function(){df_descripcion_proceso %>%
        filter(orden_citas == get_attribute(modelo, "tipo_cita")) %>%
        .$tiempos_procedimientos}) %>%
    release_selected()
}



trj_asig_espera_ausentismo_recibo = function(.trj,
                                             cant_tipos_citas_sec,
                                             p_abandono_dado_aus,
                                             inicio_c = 1,
                                             llenado_inicial = FALSE){
  
  #Esta funcion genera repite varias veces la seccion de las trayectorias
  #correspondiente al proceso de asignar, esperar, ausentarse y recibir.
  
  
  
  
  
  for (i in inicio_c:cant_tipos_citas_sec) {
    
    if (i == inicio_c && llenado_inicial){
      .trj = .trj %>% trj_asignacion_cita(orden_cita = i, t_min_entre_citas = FALSE) %>%
        trj_espera() %>%
        trj_ausentismo(orden_cita = i,
                       p_abandono_dado_ausentismo = p_abandono_dado_aus) %>%
        trj_rechazo(orden_cit = i) %>% 
        trj_reproceso(orden_cita = i) %>% 
        trj_recibe_cita() 
      
      
      if(i == 1){
        
        # Es necesario que si pasa de Cupo Nuevo a Impresión entonces se 
        # re asigne el doctor basado en la cola de Impresión
        .trj = .trj %>% set_attribute("id_doc", function(){
          f_asignar_doc_a_paciente(t_i = get_attribute(modelo, "t_inicio"),
                                   inicio_c = 2)})
      }
      
    } else {
      
      .trj = .trj %>% trj_asignacion_cita(orden_cita = i, t_min_entre_citas = TRUE) %>%
        trj_espera() %>%
        trj_ausentismo(orden_cita = i,
                       p_abandono_dado_ausentismo = p_abandono_dado_aus) %>%
        trj_rechazo(orden_cit = i) %>%
        trj_reproceso(orden_cita = i) %>% 
        trj_recibe_cita()
      
    }
  }
  
  return(.trj)
  
}


# ______________________________________________________________________________
# Funciones para el inicio lleno
# ______________________________________________________________________________

f_crear_trjs_inicio_lleno = function(cant_citas = max(df_descripcion_proceso$orden_citas), 
                                     cant_docs = cantidad_doctores){
  
  # Para simular el inicio lleno lo que se hace es que se agregan una cantidad de 
  # trayectorias igual a la (cantidad de citas * doctores).
  
  # Estas trayectorias se les va a inyectar en el puro puro inicio de la simulacion
  # una cantidad equivalente de personas a los dias MaxFecha presentes en el Excel.
  
  # Es decir, los pacientes que ya estaban tienen trayectorias recortadas y no 
  # empiezan en el puro inicio.
  
  #Esta funcion permite crear las trayectorias para llenar el sistema en el 
  #momento 0 segun las maximas fechas dadas en el archivo de MaxFechas.
  
  #Basicamente se crea una lista de trayectorias con todas las combinaciones de 
  #cita-doctor. Luego otra funcion se va a encargar de rellenar con pacientes.
  
  li = list()
  li2 = list()
  
  for(i in 1:cant_citas){
    for(j in 1:cant_docs){
      
      
      paciente_trajectoria_relleno_inicial =
        trajectory(paste("Trayectoria Inicio Lleno. Cita:",i,"Doc:",j)) %>%
        #Asignacion de id_paciente y de numero de doctor
        set_attribute("id_paciente" ,function(){f_asignar_id_paciente()}) %>%
        
        
        #Mensaje a Imprimir en la consola.
    
        set_attribute("Limpiar Consola", function(){f_limpiar_consola()}) %>%
        
        set_attribute("Limpiar Consola", function(){f_mensaje_consola(
          "Corriendo simulación..."
        )}) %>%
        set_attribute("Limpiar Consola", function(){f_mensaje_consola(
          "Llenado Inicial del Sistema"
        )}) %>%
        
        
        log_(function() {
          paste0(
            
            "Progreso: ", 
            round(100*get_attribute(modelo, "id_paciente")/cant_pac_agregar_total, 2),
            "%"
            
          )}, level = 2) %>% 
        
        
        log_(function() {
          paste0(
            
            "Pacientes Agregados: ", get_attribute(modelo, "id_paciente") , "/", cant_pac_agregar_total
            
            )}, level = 2) %>% 
        
        
        
        set_attribute("t_inicio", function(){
          f_registrar_t_inicio(id_p = get_attribute(modelo, "id_paciente"),
                               id_doctor = get_attribute(modelo,"id_doc"),
                               t_sim = simmer::now(modelo))}) %>%
        
        #Notese que aqui como el doc no es asignado basado en prontitud, solo
        #se asigna de un solo, entonces no es necesario recurrir a la funcion
        #de asignar doctor. 
        set_attribute("id_doc", j) %>% 
        
        #La funcion a continuacion, con el parametro inicio_c permite decidir
        #en que numero de cita inicia la trayectoria. Asi es como se logra
        #introducir personas en colas en la mitad del proceso en el tiempo 0
        #y crear artificialmente ese estado inicial lleno.
        
        trj_asig_espera_ausentismo_recibo(max(df_descripcion_proceso$orden_citas),
                                          p_abandono_dado_aus = p_abandono_aus,
                                          inicio_c = i,
                                          llenado_inicial = TRUE)
      
      li[[j]] = paciente_trajectoria_relleno_inicial
    }
    
    li2[[i]] = li
  }
  
  return(li2)
}

f_cant_pac_agregar_inicio_lleno = function(agenda_g_base = agenda_global_base,
                                           df_max_fechas = df_maxfechas,
                                           df_descrip = df_descripcion_proceso) {
  
  #### FUNCION PARA ESTIMAR LAS CANTIDADES DE PACIENTES A INTRODUCIR CON MAXFECHA
  #### Es importante mencionar que se debe de correr la simulacion en el instante
  #### en el cual se realizo la medicion para que la cantidad de pacientes sea la
  #### correcta.
  
  #### En realidad dado que si hay un cambio de horario lo que se afecta es la
  #### agenda global_base_2 entonces ese cambio si se va a ver correctamente
  #### previo al cambio de horario
  
  df = agenda_g_base %>% 
    left_join(df_max_fechas, by = c("id_doc", "campo_cita")) %>% 
    filter(fecha < fecha_final) %>% 
    group_by(id_doc, campo_cita) %>% summarise(n = n()) %>%
    arrange(id_doc, factor(campo_cita, levels = df_descrip$tipos_citas)) %>% 
    return()
}

f_crear_generadores_inicio_lleno = function(.env,
                                            li_trjs = li_pac_trajectoria_incompleta,
                                            df_cant_pac = df_cant_pacientes_a_agregar,
                                            df_descrip = df_descripcion_proceso,
                                            inic_vacio = inicio_vacio){
  
  if(inic_vacio){
    
    return(.env)
    
  } else {
    
    #Se determinan la cantidad de pacientes a introducir basado en las maximas
    #fechas.
    #Este loop agrega los generadores para cada combinacion de paciente-doctor
    
    df_cant_pac = df_cant_pac %>% 
      left_join(df_descrip %>% select("campo_cita" = tipos_citas, orden_citas),
                by = "campo_cita") %>% mutate(doc = parse_number(id_doc))
    
    for (n_cita in 1:length(li_trjs)){
      for(n_doc in 1:length(li_trjs[[n_cita]])){
        
        cant_pac_agregar = df_cant_pac %>% 
          filter(orden_citas == n_cita, doc == n_doc) %>% .$n
        
        
        if(length(cant_pac_agregar) == 0){
          .env = .env
        } else {
          .env = .env %>% 
            add_generator(paste0("paciente_C",n_cita,"_D",n_doc,"_"),
                          li_trjs[[n_cita]][[n_doc]],
                          at(rep(0,cant_pac_agregar)),
                          mon = 0) 
        }
      }
    }
    return(.env)
  }
}

# ______________________________________________________________________________
# Funciones para Impresion de Consola
# ______________________________________________________________________________

f_limpiar_consola = function(){
  shell("cls")
  cat("\014")
  return(0)
}

f_mensaje_consola = function(mensaje){
  cat(mensaje)
  cat("\n")
  return(0)
}




#_______________________________________________________________________________
# Aplicacion de Funciones para la creacion de objetos importantes
#_______________________________________________________________________________

horarios_actuales = f_leer_archivo(here("Input","Horarios_Actuales.xlsx"))

#Agenda Global que registra todas las citas agendadas durante la simulacion
agenda_global_base = f_crear_agenda_global(horarios_actuales,
                                           fecha_i_LUNES_ = fecha_inicio_simulacion,
                                           fecha_f_DOMINGO_ = fecha_final_agenda)
if(cambio_de_horario){
  # Si se escoje este Setting entonces la agenda global base se llega a componer
  # de dos secciones distintas. Una antes del cambio y otra despues del cambio
  horarios_nuevos = f_leer_archivo(here("Input","Horarios_Nuevos.xlsx"))
  agenda_global_base_2 = f_crear_agenda_global(horarios_nuevos,
                                               fecha_i_LUNES_ = fecha_inicio_simulacion,
                                               fecha_f_DOMINGO_ = fecha_final_agenda)
  agenda_global_base = rbind(agenda_global_base %>% filter(fecha < fecha_cambio_horario),
                             agenda_global_base_2 %>% filter(fecha >= fecha_cambio_horario))
  rm(agenda_global_base_2)
} else {
  horarios_nuevos = horarios_actuales
}

#Cantidad de Doctores
cantidad_doctores = length(horarios_actuales)

if (cambio_de_horario){
  cantidad_doctores = max(c(length(horarios_actuales), length(horarios_nuevos)))
}

f_listdocs = function(x){
  v =c()
  for (i in 1:x){
    g = paste0("doc",i)
    v= c(v,g)
  }
  return(v)
} 

lista_doctores = f_listdocs(cantidad_doctores)

#Matriz que registra llegadas de los pacientes durante la simulacion
mat_t_inicio_base = matrix(nrow = 0, ncol = 3)
colnames(mat_t_inicio_base) = c("id_paciente", "tiempo_sim", "doc")


#Matriz que registra ausentismos y abandonos a lo largo de la simulacion
mat_r_ausentismos_base = matrix(nrow = 0, ncol = 4)
colnames(mat_r_ausentismos_base) = c("id_paciente", "tiempo_sim", "ausentismo", "abandono")

#Matriz que registra reprocesos a lo largo de la simulacion
mat_r_reproceso_base = matrix(nrow = 0, ncol = 3)
colnames(mat_r_reproceso_base) = c("id_paciente", "tiempo_sim", "reproceso")

#Matriz que registra rechazos a lo largo de la simulacion
mat_r_rechazo_base = matrix(nrow = 0, ncol = 3)
colnames(mat_r_rechazo_base) = c("id_paciente", "tiempo_sim", "rechazo")

#Contador de pacientes para ir registrando su ID
contador_pacientes_id_base = 1

#Tiempo final en minutos

tiempo_final_minutos = 
  (difftime(fecha_final_simulacion,fecha_inicio_simulacion,units = "mins") %>% 
     as.numeric()) + 24*60 #queremos el final del dia

#Cantidad de dias de simulacion
cantidad_dias_simulacion = ceiling(tiempo_final_minutos/(24*60))

#_______________________________________________________________________________
#Alertas por Falta de Congruencia
#_______________________________________________________________________________
#En esta seccion se establecen una serie de Alertas para evitar que a la hora de
#correr el modelo este presente errores porque no hay congruencia en los Inputs
#que son dados.



#_______________________________________________________________________________
#Variables afectadas en el ambiente global a lo largo de la simulacion
#_______________________________________________________________________________

agenda_global = agenda_global_base

contador_pacientes_id = contador_pacientes_id_base

mat_r_ausentismos = mat_r_ausentismos_base

mat_r_reproceso = mat_r_reproceso_base

mat_r_rechazo = mat_r_rechazo_base

mat_t_inicio = mat_t_inicio_base

#_______________________________________________________________________________
# Simulacion
#_______________________________________________________________________________
startTime <- Sys.time()


modelo = simmer('Prostodoncia', log_level = 2)
#Creamos recursos


modelo %>%
  f_crear_recursos(df_descripcion_proceso, cantidad_doctores,horarios_actuales)


#Trayectoria

registro_del_tiempo_trayectoria =
  trajectory("Registro de tiempo") %>%
  
  set_attribute("Limpiar Consola", function(){f_limpiar_consola()}) %>% 
  
  set_attribute("Limpiar Consola", function(){f_mensaje_consola(
    "Corriendo simulación..."
  )}) %>%
  set_attribute("Limpiar Consola", function(){f_mensaje_consola(
    "Simulando proceso de agendamiento, espera y recepción de citas"
  )}) %>%
  
  log_(function() {paste0("Progreso: ",
                          (round((simmer::now(modelo)/tiempo_final_minutos)*100, 2)),
                          "%")}, level = 2) %>%
  log_(function(){paste0("Días Transcurridos: ",
                         ceiling(simmer::now(modelo)/(24*60)),
                         "/",
                         cantidad_dias_simulacion)}, level = 2)



paciente_trajectoria_completa =
  trajectory("Trayectoria de un paciente") %>%
  #Asignacion de id_paciente y de numero de doctor
  set_attribute("id_paciente" ,function(){f_asignar_id_paciente()}) %>%
  set_attribute("t_inicio", function(){
    f_registrar_t_inicio(id_p = get_attribute(modelo, "id_paciente"),
                         id_doctor = get_attribute(modelo,"id_doc"),
                         t_sim = simmer::now(modelo))}) %>%
  
  #Debe ocurrir la trajectoria de valoracion primero con el doctor disponible más
  #cercano 
  #_________________________________________________
  set_attribute("id_doc", function(){
    f_asignar_doc_a_paciente(t_i = get_attribute(modelo, "t_inicio"),
                             inicio_c = 1)}) %>%
  
  trj_asig_espera_ausentismo_recibo(cant_tipos_citas_sec = 1,
                                    p_abandono_dado_aus = p_abandono_aus,
                                    inicio_c = 1) %>% 
  #_________________________________________________
  #Ahora sí se le asigna un único doctor basado en la cola de impresion
  #de ahora en adelante
  set_attribute("id_doc", function(){
    f_asignar_doc_a_paciente(t_i = get_attribute(modelo, "t_inicio"),
                             inicio_c = 2)}) %>%
  
  trj_asig_espera_ausentismo_recibo(max(df_descripcion_proceso$orden_citas),
                                    p_abandono_dado_aus = p_abandono_aus,
                                    inicio_c = 2)

#Trayectorias para rellenar previo al inicio

if (!inicio_vacio) {
  li_pac_trajectoria_incompleta = f_crear_trjs_inicio_lleno()
  df_cant_pacientes_a_agregar = f_cant_pac_agregar_inicio_lleno()
  
  cant_pac_agregar_total = sum(df_cant_pacientes_a_agregar$n)
  
  #En caso de que se agregó un doctor, o hay algún doctor que no fue colocado
  #En el excel de inicio lleno, se procede a modificar df_cant_pacientes_a_agregar
  #Para incluirlos con valores de 0
  
  if(df_cant_pacientes_a_agregar$id_doc %>% table() %>% length() != cantidad_doctores){
    todas_comb = expand.grid(lista_doctores, df_descripcion_proceso$tipos_citas) %>% 
      as.matrix() %>% as_tibble()
    
    todas_comb = todas_comb %>% mutate(Var3 = 0)
    
    names(todas_comb) = names(df_cant_pacientes_a_agregar)
    
    
    df_cant_pacientes_a_agregar = df_cant_pacientes_a_agregar %>% 
      full_join(todas_comb, by = c("id_doc", "campo_cita"))%>% 
      mutate(n = coalesce(n.x, n.y))  %>% 
      select(id_doc, campo_cita, n)
  }
}


modelo %>%
  f_crear_generadores_inicio_lleno(inic_vacio = inicio_vacio) %>% 
  add_generator("paciente",
                paciente_trajectoria_completa,
                function(){f_generar_pacientes(tasa_llegadas = 1/tasa_llegadas_base)},
                mon = 0) %>%
  
  add_generator("registro_tiempo", registro_del_tiempo_trayectoria,
                function(){24*60}, mon = 0) %>%
  
  simmer::run(until = tiempo_final_minutos)
endTime <- Sys.time()


print("Simulación Finalizada con Éxito!")

print(endTime - startTime)
#_______________________________________________________________________________
# Ajustes finales
#_______________________________________________________________________________

#Añadir los tiempos de inicio, ausentismos y abandonos

df_t_inicio = as_tibble(mat_t_inicio)
df_t_inicio = df_t_inicio %>% select(id_paciente,
                                     "tiempo_inicio" = tiempo_sim)


agenda_global = agenda_global %>% left_join(df_t_inicio, by = "id_paciente")



df_r_ausentismo = as_tibble(mat_r_ausentismos)
df_ausentismo = df_r_ausentismo %>% mutate(ausentismo = as.logical(ausentismo),
                                           abandono = as.logical(abandono))

agenda_global = agenda_global %>% left_join(df_r_ausentismo, by = c("tiempo_sim","id_paciente"))

df_reproceso = as_tibble(mat_r_reproceso) %>% mutate(reproceso = as.logical(reproceso))

df_rechazo = as_tibble(mat_r_rechazo) %>% mutate(rechazo= as.logical(rechazo))

agenda_global = agenda_global %>% left_join(df_reproceso, by = c("tiempo_sim","id_paciente"))
agenda_global = agenda_global %>% left_join(df_rechazo, by = c("tiempo_sim","id_paciente"))

agenda_global = agenda_global %>% mutate(ausentismo =
                                           case_when(campo_tomado & (is.na(ausentismo)) ~ FALSE,
                                                     is.na(ausentismo) ~ NA,
                                                     ausentismo == 1 ~ TRUE),
                                         abandono = as.logical(if_else(!ausentismo, FALSE, abandono)))

agenda_global = agenda_global %>% mutate(reproceso = 
                                           case_when(campo_tomado & (is.na(reproceso)) ~ FALSE,
                                                     is.na(reproceso) ~ NA,
                                                     reproceso == 1 ~ TRUE,
                                                     reproceso == 0 ~ FALSE))

agenda_global = agenda_global %>% mutate(rechazo = 
                                           case_when(campo_tomado & (is.na(rechazo)) ~ FALSE,
                                                     is.na(rechazo) ~ NA,
                                                     rechazo == 1 ~ TRUE,
                                                     rechazo == 0 ~ FALSE))

# Se levanta una alerta si algun paciente en agarro la ultima cita de cualquiera
# de las combinaciones doctor-cita. Es decir, la cola va mas alla de lo que establecio
# en la variable fecha_final_agenda
agenda_global = agenda_global %>% mutate(fecha_dia = fecha %>% date(),
                                         fecha_hora = fecha %>% format("%H:%M:%S")) %>% 
  select(fecha_dia,fecha_hora,everything())


cola_mas_alla = agenda_global %>% 
  group_by(id_doc, campo_cita) %>% 
  filter(fecha_dia == max(fecha_dia)) %>% 
  filter(fecha_hora == max(fecha_hora)) %>% 
  filter(campo_tomado)

if (nrow(cola_mas_alla) != 0) {
  print(paste("Una de las colas tiene un tiempo superior la fecha_final_agenda establecida", 
              fecha_final_agenda))
  print("A continuacion se muestra el ultimo registro obtenido")
  print(cola_mas_alla)
  cola_sup_a_fecha_final = TRUE
  
  Sys.sleep(4)
  
} else {
  cola_sup_a_fecha_final = FALSE
}

# Se elimina de la agenda global todos los NAs posteriores a la ultima fecha para
# cada combinacion doctor-cita

ult_cita = agenda_global %>% group_by(id_doc, campo_cita) %>%
  filter(campo_tomado) %>%
  filter(fecha_dia == max(fecha_dia)) %>%
  filter(fecha_hora == max(fecha_hora)) %>%
  select(id_doc,campo_cita,"t_max_linea" = tiempo_sim)

agenda_global = agenda_global %>% 
  left_join(ult_cita, by = c("id_doc", "campo_cita")) %>%
  filter(tiempo_sim <= t_max_linea) %>% 
  select(-t_max_linea)

#Añadir los settings en una unica tabla para agregar al excel de guardado

df_settings = tibble(
  "inicio_vacio" = inicio_vacio %>% as.character(),
  "cambio_de_horario" = cambio_de_horario%>% as.character(),
  "s_ausentismo_por_hora" = s_ausentismo_por_hora%>% as.character(),
  "s_ausentismo_por_tipo_cita" = s_ausentismo_por_tipo_cita%>% as.character(),
  "guardar" = guardar %>% as.character(),
  "nombre_archivo_guardado" = nombre_archivo_guardado%>% as.character(),
  
  "tasa_llegadas_base" = tasa_llegadas_base%>% as.character(),
  "fecha_inicio_simulacion" = fecha_inicio_simulacion%>% as.character(),
  "fecha_cambio_horario" = ifelse(cambio_de_horario, fecha_cambio_horario%>% as.character(), NA),
  "fecha_final_simulacion" = fecha_final_simulacion%>% as.character(),
  "fecha_final_agenda" = fecha_final_agenda %>% as.character(),
  "p_abandono_aus" = p_abandono_aus%>% as.character(),
  "p_reproceso_control" = p_reproceso_control %>% as.character(),
  "p_rechazo_cuponuevo" = p_rechazo_cuponuevo %>% as.character(),
  "tiempo_de_corrida" = tiempo_de_corrida%>% as.character(),
  "duracion_corrida" = (endTime - startTime) %>% as.character(),
  "cola_sup_a_fecha_final" = cola_sup_a_fecha_final %>% as.character(),
) %>% pivot_longer(names_to = "Setting", values_to = "Valores", cols = everything())

agenda_global = agenda_global %>% mutate(fecha_dia = as.Date(fecha),
                                         fecha_hora = format(fecha, format = "%H:%M:%S")) %>%
  select(fecha_dia, fecha_hora, everything()) %>%
  select(-fecha)

#_______________________________________________________________________________
# Guardado de informacion
#_______________________________________________________________________________

if (guardar) {
  #Esta linea tira error si intentamos guardar dos veces la agenda global
  
  
  ag_workbook = openxlsx::createWorkbook()
  
  #Hoja de Agenda Global
  ag_workbook %>% openxlsx::addWorksheet("Agenda_Global")
  ag_workbook %>% openxlsx::writeData(sheet = "Agenda_Global", agenda_global)
  
  #Hoja de Settings de la Simulacion
  ag_workbook %>% openxlsx::addWorksheet("Settings")
  ag_workbook %>% openxlsx::writeData(sheet = "Settings", df_settings)
  
  #Hoja de Descripcion del Proceso
  ag_workbook %>% openxlsx::addWorksheet("Proceso")
  ag_workbook %>% openxlsx::writeData(sheet = "Proceso", df_descripcion_proceso)
  
  #Hoja de Horarios Viejos
  
  df_horarios_actuales = f_horarios_a_excel(horarios_actuales)
  ag_workbook %>% openxlsx::addWorksheet("Horarios_Actuales")
  ag_workbook %>% openxlsx::writeData(sheet = "Horarios_Actuales", df_horarios_actuales)
  
  
  #Hojas Opcionales
  ## Hoja de Horarios Nuevos en caso de cambio de horarios
  if(cambio_de_horario){
    
    #Si hay cambios de horario se agrega en una hoja los horarios cambiados.
    rm(df_horarios_nuevos)
    df_horarios_nuevos = f_horarios_a_excel(horarios_nuevos)
    ag_workbook %>% openxlsx::addWorksheet("Horarios_Nuevos")
    ag_workbook %>% openxlsx::writeData(sheet = "Horarios_Nuevos", df_horarios_nuevos)
    
  } else {
    ag_workbook %>% openxlsx::addWorksheet("Horarios_Nuevos")
    ag_workbook %>% openxlsx::writeData(sheet = "Horarios_Nuevos", "No se escogio la opcion de horarios nuevos.")
  }
  
  ## Descipcion de Maximas Fechas
  if(!inicio_vacio) {
    ag_workbook %>% openxlsx::addWorksheet("MaxFechas_InicioLleno")
    ag_workbook %>% openxlsx::writeData(sheet = "MaxFechas_InicioLleno", df_maxfechas)
    
    ag_workbook %>% openxlsx::addWorksheet("Agreg_Pac_InicioLleno")
    ag_workbook %>% openxlsx::writeData(sheet = "Agreg_Pac_InicioLleno", df_cant_pacientes_a_agregar)
  } else {
    ag_workbook %>% openxlsx::addWorksheet("MaxFechas_InicioLleno")
    ag_workbook %>% openxlsx::writeData(sheet = "MaxFechas_InicioLleno", "No se escogio la opcion de Inicio Lleno")
    
    ag_workbook %>% openxlsx::addWorksheet("Agreg_Pac_InicioLleno")
    ag_workbook %>% openxlsx::writeData(sheet = "Agreg_Pac_InicioLleno", "No se escogio la opcion de Inicio Lleno")
    
  }
  
  ## Ausentismo por hora
  # if(s_ausentismo_por_hora) {
  #   ag_workbook %>% openxlsx::addWorksheet("MatAusentismos_hora")
  #   ag_workbook %>% openxlsx::writeData(sheet = "MatAusentismos_hora", mat_ausentismos %>% as_tibble())
  # } else {
  #   ag_workbook %>% openxlsx::addWorksheet("MatAusentismos_hora")
  #   ag_workbook %>% openxlsx::writeData(sheet = "MatAusentismos_hora", "No se escogio la opcion de Ausentismo por Hora")
  # }
  
  #Guardamos el archivo en Output
  
  nombre_archivo_guardado2 = f_guardar_varias_replicas(nombre_archivo_guardado, ag_workbook, 0)
}

#Este último paso corre el archivo que genera el HTML

if(!exists("renderizar")){
  renderizar = FALSE
}


if(renderizar && guardar){
  
  cat("\014")
  shell("cls")
  cat("Creando Reporte de Métricas")
  cat("\n")
  
  rmarkdown::find_pandoc()
  
  rmarkdown::render(here("ScriptsR", 'Reporte-Metricas-Sim.Rmd'), 
                    output_file = here('Output',paste0(nombre_archivo_guardado2, '.html')),
                    params = list(nombre_archivo_g = paste0(nombre_archivo_guardado2, '.xlsx'),
                                  directorio_archivo = here()),
                    encoding = "UTF-8")
  
  
  paste("Reporte de Métricas creado con éxito!")
  
  cronometro_final = Sys.time()
  
  print("Tiempo durado en ejecutar el programa: ")
  print(cronometro_final - cronometro_inicio)
  
  Sys.sleep(4)
  
  shell.exec(here("Output", paste0(nombre_archivo_guardado2, ".html")))
}



return(agenda_global)
}

simulacion_AgSim(ruta = s_ruta_dir, render = s_renderizar, guardar = s_guardar )