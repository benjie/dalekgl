TAN30 = Math.tan(Math.PI/6)
class Hexagon
  ###
     1 ____ 2
     /|\  /|\
   6/ | \/ | \3
    \ | /\ | /
    5\|/__\|/4
  ###
  constructor: (@x, @y, @size) ->

  verticiesData: ->
    edgeLength = @size
    # T = O / A
    # T(30) = edgeLength/2 / A
    # A = edgeLength / (2 * Tan(30))
    hexHeight = edgeLength / TAN30
    verticies = [
      [@x - edgeLength / 2, @y + hexHeight / 2]
      [@x + edgeLength / 2, @y + hexHeight / 2]
      [@x + edgeLength,     @y]
      [@x + edgeLength / 2, @y - hexHeight / 2]
      [@x - edgeLength / 2, @y - hexHeight / 2]
      [@x - edgeLength,     @y]
    ]
    result = []
    colours = [
      [1, 0, 0]
      [0, 1, 0]
      [0, 0, 1]
      [1, 1, 0]
      [1, 0, 1]
      [0, 1, 1]
    ]
    for [x, y], i in verticies
      result.push x
      result.push y
      result.push colours[i][0]
      result.push colours[i][1]
      result.push colours[i][2]
    return result

  facesData: (n) ->
    # n is how many previous verticies there are
    faces = [
      1, 4, 2,
      2, 4, 3,
      1, 5, 4,
      1, 6, 5
    ]
    faces.map (i) -> i - 1 + n

window.APP = APP = new class
  VERTEX: 2
  FRAGMENT: 3

  vertexShaderSource: """
    attribute vec2 position;
    attribute vec3 color;

    varying vec3 vColor;
    void main(void) {
      gl_Position = vec4(position, 0., 1.);
      vColor=color;
    }
    """

  fragmentShaderSource: """
    precision mediump float;

    varying vec3 vColor;
    void main(void) {
      gl_FragColor = vec4(vColor, 1.);
    }
    """

  getShader: (type, source) ->
    shader = @GL.createShader(type)
    @GL.shaderSource(shader, source)
    @GL.compileShader(shader)
    unless @GL.getShaderParameter(shader, @GL.COMPILE_STATUS)
      alert("ERROR IN #{if type is @GL.VERTEX_SHADER then 'vertex' else 'fragment'} SHADER : #{@GL.getShaderInfoLog(shader)}")
      return false
    return shader

  initCanvas: ->
    canvas = document.getElementById("canvas")
    canvas.width = window.innerWidth
    canvas.height = window.innerHeight
    @canvas = canvas
    return true

  initGLContext: ->
    @GL = @canvas.getContext("experimental-webgl", {antialias: true})
    return true

  initShaders: ->
    vertexShader = @getShader(@GL.VERTEX_SHADER, @vertexShaderSource)
    fragmentShader = @getShader(@GL.FRAGMENT_SHADER, @fragmentShaderSource)
    shaderProgram = @GL.createProgram()
    @GL.attachShader(shaderProgram, vertexShader)
    @GL.attachShader(shaderProgram, fragmentShader)
    @GL.linkProgram(shaderProgram)

    @shaderProgram = shaderProgram
    @_color = @GL.getAttribLocation(shaderProgram, "color")
    @_position = @GL.getAttribLocation(shaderProgram, "position")

    @GL.enableVertexAttribArray(@_color)
    @GL.enableVertexAttribArray(@_position)

    return true

  initTriangle: ->
    size = 0.2
    fiddle =
      x: 1/10
      y: 1/10 * TAN30 / 2
    offsetX = size * (2 + fiddle.x)
    offsetY = size * (1/(2*TAN30) + fiddle.y)
    @hexagons = []
    for row in [-5..5]
      for col in [-5..5]
        if Math.abs(row % 2) is 1
          @hexagons.push new Hexagon col * (offsetX + size), row * offsetY, size
        else
          @hexagons.push new Hexagon (3 + fiddle.x) * size/2 + col * (offsetX + size), row * offsetY, size
          #@hexagons.push new Hexagon col * offsetX,  row * 2 * offsetY, size

    @hexagons2 = [
      new Hexagon 0, 0, size
      new Hexagon offsetX, offsetY, size
      new Hexagon offsetX, -offsetY, size
      new Hexagon -offsetX, offsetY, size
      new Hexagon -offsetX, -offsetY, size
    ]
    ###
    new Hexagon 0,  0.4, 0.2
    new Hexagon 0, -0.4, 0.2
    new Hexagon -0.3, 0.2, 0.2
    new Hexagon -0.3, -0.2, 0.2
    new Hexagon 0, 0, 0.2
    new Hexagon 0.3, 0.2, 0.2
    new Hexagon 0.3, -0.2, 0.2
    ###
    triangleVertexData = []
    triangleFacesData = []
    for hexagon, i in @hexagons
      verticiesData = hexagon.verticiesData()
      triangleVertexData.push datum for datum in verticiesData
      facesData = hexagon.facesData(i * 6)
      triangleFacesData.push datum for datum in facesData

    @triangleVertex = @GL.createBuffer()
    @GL.bindBuffer(@GL.ARRAY_BUFFER, @triangleVertex)
    @GL.bufferData(@GL.ARRAY_BUFFER, new Float32Array(triangleVertexData), @GL.STATIC_DRAW)

    @triangleFaces = @GL.createBuffer()
    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, @triangleFaces)
    @GL.bufferData(@GL.ELEMENT_ARRAY_BUFFER, new Uint16Array(triangleFacesData), @GL.STATIC_DRAW)

    return true

  init: ->
    try
      @initCanvas()
      @initGLContext()
      @initShaders()
      @initTriangle()
      @GL.clearColor(0.0, 0.0, 0.0, 0.0)
      return true
    catch e
      console.error e.stack
      alert("You are not compatible :(")
      return false

  draw: =>
    @GL.viewport(0.0, 0.0, @canvas.width, @canvas.height)
    @GL.clear(@GL.COLOR_BUFFER_BIT)

    @GL.bindBuffer(@GL.ARRAY_BUFFER, @triangleVertex)
    @GL.vertexAttribPointer(@_position, 2, @GL.FLOAT, false, 4*(2+3), 0)
    @GL.vertexAttribPointer(@_color, 3, @GL.FLOAT, false, 4*(2+3), 2*4)

    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, @triangleFaces)
    @GL.drawElements(@GL.TRIANGLES, @hexagons.length * 4 * 3, @GL.UNSIGNED_SHORT, 0)
    @GL.flush()

    window.requestAnimationFrame(@draw)

  run: ->
    @GL.useProgram(@shaderProgram)
    @draw()

  start: =>
    @init() and @run()

window.addEventListener 'DOMContentLoaded', APP.start, false
