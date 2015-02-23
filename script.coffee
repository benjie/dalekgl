TAN30 = Math.tan(Math.PI/6)
OUTER_RING_RADIUS = 0.95
INNER_RING_RADIUS = 0.7
HEXAGONS_HIGH = 55

distanceFromCenter = (v) ->
  (v[0] ** 2 + v[1] ** 2) ** 0.5

class Hexagon
  ###
     1 ____ 2
     /|\  /|\
   6/ | \/ | \3
    \ | /\ | /
    5\|/__\|/4
  ###
  constructor: (@x, @y, @size, @maxRadius, @minRadius) ->

  data: (n) ->
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

    faces = [
      [1, 4, 2]
      [2, 4, 3]
      [1, 5, 4]
      [1, 6, 5]
    ]

    # ==================================================
    # Filtering

    for vertex in verticies
      r = distanceFromCenter(vertex)
      isInside = (@minRadius <= r <= @maxRadius)
      vertex.push isInside

    moveVertexToward = (vertex, otherVertex, minR, maxR) ->
      # find the point along the line previousVertex..vertex where r hits the edge
      guess = vertex.slice()
      badBound = vertex
      goodBound = otherVertex

      moveToward = (v) ->
        guess[0] = (guess[0] + v[0]) / 2
        guess[1] = (guess[1] + v[1]) / 2
        return

      moveToward(goodBound)

      for i in [0..5]
        if minR <= distanceFromCenter(guess) <= maxR
          goodBound = guess
          moveToward badBound
        else
          badBound = guess
          moveToward goodBound
      vertex[0] = guess[0]
      vertex[1] = guess[1]
      return

    for vertex, i in verticies when vertex[2] is false
      # XXX: THIS CODE IS WONKY, FIX IT!
      #
      # Aim is to move any out of bounds verticies so that they're just inside the bounds
      target = vertex
      for j, k in [1, 5, 2, 4, 3]
        other = verticies[(i + j) % 6]
        if other[2]
          vertex[0] = target[0]
          vertex[1] = target[1]
          moveVertexToward(vertex, other, @minRadius, @maxRadius)
          break
        if k % 2 == 1
          target = other

    for face, i in faces by -1
      inside = false
      for vertexIndex in face
        vertex = verticies[vertexIndex-1]
        inside ||= vertex[2]
      unless inside
        faces.splice(i, 1)



    # ==================================================
    # Output

    facesData = []
    verticiesData = []
    if faces.length > 0
      for face in faces
        for point in face
          facesData.push point - 1 + n

      colours = [
        [1, 0, 0]
        [0, 1, 0]
        [0, 0, 1]
        [1, 1, 0]
        [1, 0, 1]
        [0, 1, 1]
      ]
      for [x, y], i in verticies
        verticiesData.push x
        verticiesData.push y
        verticiesData.push colours[i][0]
        verticiesData.push colours[i][1]
        verticiesData.push colours[i][2]
    return verticiesData: verticiesData, facesData: facesData

window.APP = APP = new class
  VERTEX: 2
  FRAGMENT: 3

  vertexShaderSource: """
    attribute vec2 position;
    attribute vec3 color;
    uniform float factor;

    varying vec3 vColor;
    void main(void) {
      vec2 pos = position;
      pos.x *= factor;
      gl_Position = vec4(pos, 0., 1.);
      vColor=color;
    }
    """

  fragmentShaderSource: """
    precision mediump float;

    varying vec3 vColor;
    void main(void) {
      gl_FragColor = vec4(0, 0, 1, 1.);
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

  resizeCanvas: =>
    @canvas.width = window.innerWidth
    @canvas.height = window.innerHeight
    return

  initCanvas: ->
    @canvas = document.getElementById("canvas")
    @resizeCanvas()
    window.addEventListener 'resize', @resizeCanvas, true
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
    @_factor = @GL.getUniformLocation(shaderProgram, "factor")

    @GL.enableVertexAttribArray(@_color)
    @GL.enableVertexAttribArray(@_position)

    return true

  initOuterHexagons: ->
    hexagonsHigh = HEXAGONS_HIGH
    widthToHeight = 16/9 # 16:9 ratio

    size = 2 / (hexagonsHigh / TAN30)
    fiddle =
      x: 3/10
      y: 3/10 * TAN30 / 2
    offsetX = size * (2 + fiddle.x)
    offsetY = size * (1/(2*TAN30) + fiddle.y)
    @hexagons = []
    for row in [-hexagonsHigh..hexagonsHigh]
      highIndex = hexagonsHigh * widthToHeight * TAN30 / 2
      for col in [-highIndex..highIndex]
        x =
          if Math.abs(row % 2) is 1
            col * (offsetX + size)
          else
            (3 + fiddle.x) * size/2 + col * (offsetX + size)
        y = row * offsetY
        @hexagons.push new Hexagon x, y, size, Infinity, OUTER_RING_RADIUS

    triangleVertexData = []
    triangleFacesData = []
    for hexagon, i in @hexagons
      previousVerticiesCount = triangleVertexData.length / 5
      {verticiesData, facesData} = hexagon.data(previousVerticiesCount)
      triangleVertexData.push datum for datum in verticiesData
      triangleFacesData.push datum for datum in facesData

    @triangleVertexData = triangleVertexData
    @triangleVertex = @GL.createBuffer()
    @GL.bindBuffer(@GL.ARRAY_BUFFER, @triangleVertex)
    @GL.bufferData(@GL.ARRAY_BUFFER, new Float32Array(triangleVertexData), @GL.STATIC_DRAW)

    @triangleFacesData = triangleFacesData
    @triangleFaces = @GL.createBuffer()
    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, @triangleFaces)
    @GL.bufferData(@GL.ELEMENT_ARRAY_BUFFER, new Uint16Array(triangleFacesData), @GL.STATIC_DRAW)

    return true

  init: ->
    try
      @initCanvas()
      @initGLContext()
      @initShaders()
      @initOuterHexagons()
      @GL.clearColor(0.0, 0.0, 0.0, 0.0)
      return true
    catch e
      console.error e.stack
      alert("You are not compatible :(")
      return false

  draw: =>
    @GL.viewport(0.0, 0.0, @canvas.width, @canvas.height)
    @GL.clear(@GL.COLOR_BUFFER_BIT)

    @GL.uniform1f(@_factor, canvas.height / canvas.width)

    @GL.bindBuffer(@GL.ARRAY_BUFFER, @triangleVertex)
    @GL.vertexAttribPointer(@_position, 2, @GL.FLOAT, false, 4*(2+3), 0)
    @GL.vertexAttribPointer(@_color, 3, @GL.FLOAT, false, 4*(2+3), 2*4)

    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, @triangleFaces)
    @GL.drawElements(@GL.TRIANGLES, @triangleFacesData.length, @GL.UNSIGNED_SHORT, 0)
    @GL.flush()

    window.requestAnimationFrame(@draw)
    return

  run: ->
    @GL.useProgram(@shaderProgram)
    @draw()

  start: =>
    @init() and @run()

window.addEventListener 'DOMContentLoaded', APP.start, false
