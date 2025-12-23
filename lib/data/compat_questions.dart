// lib/data/compat_questions.dart
import 'package:flutter/material.dart';

class CompatOption {
  final String id;
  final String label;

  const CompatOption({required this.id, required this.label});
}

class CompatQuestion {
  final String id;
  final String title;
  final List<CompatOption> options;
  /// Si es true, puede elegir varias opciones; si es false, solo una.
  final bool multi;

  const CompatQuestion({
    required this.id,
    required this.title,
    required this.options,
    this.multi = false,
  });
}

/// Preguntas pensadas para un público LDS, incluyendo hábitos de ejercicio.
const List<CompatQuestion> compatQuestions = [
  CompatQuestion(
    id: 'q1_faith',
    title: '¿Qué tan central es el Evangelio de Jesucristo en tu vida diaria?',
    options: [
      CompatOption(id: 'low', label: 'Importante, pero no central'),
      CompatOption(id: 'mid', label: 'Muy importante'),
      CompatOption(id: 'high', label: 'Es el centro de todo lo que hago'),
    ],
  ),
  CompatQuestion(
    id: 'q2_sabbath',
    title: '¿Cómo vives el día de reposo?',
    options: [
      CompatOption(id: 'flex', label: 'Soy flexible, no siempre asisto'),
      CompatOption(id: 'regular', label: 'Estoy trabajando en ser constante'),
      CompatOption(id: 'strict', label: 'Lo cuido mucho y asisto siempre que puedo'),
    ],
  ),
  CompatQuestion(
    id: 'q3_scripture',
    title: '¿Con qué frecuencia tienes estudio personal de las Escrituras y oración?',
    options: [
      CompatOption(id: 'rare', label: 'Casi nunca'),
      CompatOption(id: 'sometimes', label: 'Algunas veces a la semana'),
      CompatOption(id: 'daily', label: 'Diariamente, o casi diario'),
    ],
  ),
  CompatQuestion(
    id: 'q4_temple',
    title: '¿Qué papel tiene el templo en tu vida?',
    options: [
      CompatOption(id: 'future', label: 'Todavía es algo que quiero mejorar'),
      CompatOption(id: 'sometimes', label: 'Voy cuando puedo'),
      CompatOption(id: 'priority', label: 'Es una prioridad espiritual para mí'),
    ],
  ),
  CompatQuestion(
    id: 'q5_callings',
    title: '¿Cómo ves el servicio y los llamamientos en la Iglesia?',
    multi: true,
    options: [
      CompatOption(id: 'duty', label: 'Como un deber importante'),
      CompatOption(id: 'joy', label: 'Como una oportunidad de crecer'),
      CompatOption(id: 'balance', label: 'Trato de equilibrarlo con mi vida personal'),
      CompatOption(id: 'support', label: 'Prefiero apoyar más desde “segunda fila”'),
    ],
  ),
  CompatQuestion(
    id: 'q6_lifestyle',
    title: 'En cuanto a estilo de vida (Palabra de Sabiduría, entretenimiento, límites personales)…',
    options: [
      CompatOption(id: 'relaxed', label: 'Soy más relajado y flexible'),
      CompatOption(id: 'moderate', label: 'Busco un punto medio saludable'),
      CompatOption(id: 'strict', label: 'Procuro vivir estándares muy claros'),
    ],
  ),
  CompatQuestion(
    id: 'q7_exercise',
    title: '¿Cómo son tus hábitos de ejercicio o cuidado físico?',
    options: [
      CompatOption(id: 'low', label: 'Casi no hago ejercicio'),
      CompatOption(id: 'mid', label: 'Trato de moverme algunas veces a la semana'),
      CompatOption(id: 'high', label: 'Hago ejercicio constante y es importante para mí'),
    ],
  ),
  CompatQuestion(
    id: 'q8_free_time',
    title: '¿Cómo sueles pasar tu tiempo libre?',
    multi: true,
    options: [
      CompatOption(id: 'home', label: 'En casa, tranquilo'),
      CompatOption(id: 'social', label: 'Con amigos / familia'),
      CompatOption(id: 'church', label: 'Actividades de la Iglesia'),
      CompatOption(id: 'outdoor', label: 'Actividades al aire libre'),
      CompatOption(id: 'creative', label: 'Proyectos creativos / estudio'),
    ],
  ),
  CompatQuestion(
    id: 'q9_family',
    title: '¿Qué tan importante es para ti formar una familia eterna?',
    options: [
      CompatOption(id: 'thinking', label: 'Lo estoy pensando todavía'),
      CompatOption(id: 'important', label: 'Es algo importante en mi plan'),
      CompatOption(id: 'core', label: 'Es uno de mis objetivos centrales'),
    ],
  ),
  CompatQuestion(
    id: 'q10_kids',
    title: '¿Qué piensas sobre tener hijos?',
    options: [
      CompatOption(id: 'dont_know', label: 'Aún no lo sé'),
      CompatOption(id: 'few', label: 'Me gustaría tener pocos'),
      CompatOption(id: 'several', label: 'Me gustaría tener varios'),
      CompatOption(id: 'open', label: 'Estoy abierto a lo que el Señor disponga'),
    ],
  ),
  CompatQuestion(
    id: 'q11_money',
    title: 'En una relación, ¿cómo ves el manejo del dinero?',
    options: [
      CompatOption(id: 'separate', label: 'Cada quien maneja lo suyo'),
      CompatOption(id: 'mixed', label: 'Parte en común, parte individual'),
      CompatOption(id: 'shared', label: 'Todo en común, decisiones de equipo'),
    ],
  ),
  CompatQuestion(
    id: 'q12_differences',
    title: '¿Cómo manejas las diferencias de opinión o de carácter con tu pareja?',
    options: [
      CompatOption(id: 'avoid', label: 'Prefiero evitar el conflicto'),
      CompatOption(id: 'talk', label: 'Me gusta hablar las cosas con calma'),
      CompatOption(id: 'direct', label: 'Soy muy directo, aunque a veces intenso'),
    ],
  ),
];

/// Estilo recomendado para los botones de opción.
const double kOptionMinHeight = 56;
const EdgeInsets kOptionPadding =
    EdgeInsets.symmetric(horizontal: 16, vertical: 14);
final BorderRadius kOptionRadius = BorderRadius.circular(14);
