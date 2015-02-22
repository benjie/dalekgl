APP = new class
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
    triangleVertexData = [
      -1,-1,   0,0,1,
      1,-1,    1,1,0,
      1,1,     1,0,0
    ]
    @triangleVertex = @GL.createBuffer()
    @GL.bindBuffer(@GL.ARRAY_BUFFER, @triangleVertex)
    @GL.bufferData(@GL.ARRAY_BUFFER, new Float32Array(triangleVertexData), @GL.STATIC_DRAW)

    triangleFacesData = [0,1,2]
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
    catch e
      console.error e
      alert("You are not compatible :(")
      return false

  draw: =>
    @GL.viewport(0.0, 0.0, @canvas.width, @canvas.height)
    @GL.clear(@GL.COLOR_BUFFER_BIT)

    @GL.bindBuffer(@GL.ARRAY_BUFFER, @triangleVertex)

    @GL.vertexAttribPointer(@_position, 2, @GL.FLOAT, false, 4*(2+3), 0)
    @GL.vertexAttribPointer(@_color, 3, @GL.FLOAT, false, 4*(2+3), 2*4)

    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, @triangleFaces)
    @GL.drawElements(@GL.TRIANGLES, 3, @GL.UNSIGNED_SHORT, 0)
    @GL.flush()

    window.requestAnimationFrame(@draw)

  run: ->
    @GL.useProgram(@shaderProgram)
    @draw()

  start: =>
    @init()
    @run()

window.addEventListener 'DOMContentLoaded', APP.start, false
