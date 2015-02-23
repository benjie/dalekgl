TAN30 = Math.tan(Math.PI/6)
OUTER_RING_RADIUS = 0.95
INNER_RING_RADIUS = 0.7
HEXAGONS_HIGH = 55
SCREEN_RATIO = 16/9 # 16:9 ratio
SMALL_HEXAGONS_HIGH = 75
CIRCLE_SEGMENTS = 32
OUTER_ZOOM_FACTOR = 1.12
INNER_ZOOM_FACTOR = 1.05

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
  constructor: (@x, @y, @size, @maxRadius, @minRadius, @zoomFactor) ->

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
      px = @x / @zoomFactor
      py = @y / @zoomFactor
      for [x, y], i in verticies
        verticiesData.push x
        verticiesData.push y
        verticiesData.push px
        verticiesData.push py
    return verticiesData: verticiesData, facesData: facesData

window.APP = APP = new class
  VERTEX: 2
  FRAGMENT: 3

  vertexShaderSource: """
    attribute vec2 position;
    attribute vec2 texPosition;
    uniform float factor;
    uniform float screenRatio;
    varying vec2 vUV;

    void main(void) {
      vec2 pos = position;
      pos.x *= factor;
      gl_Position = vec4(pos, 0., 1.);
      vec2 pos2 = texPosition;
      pos2.x /= screenRatio;
      pos2 = pos2 + 1.;
      pos2 = pos2 / 2.;
      vUV = pos2;
    }
    """

  fragmentShaderSource: """
    precision mediump float;
    uniform sampler2D sampler;
    varying vec2 vUV;

    void main(void) {
      gl_FragColor = texture2D(sampler, vUV);
    }
    """

  bumpVertexShaderSource: """
    attribute vec2 position;
    uniform float factor;
    uniform float screenRatio;
    varying vec2 vUV;
    varying float r;

    void main(void) {
      vec2 pos = position;
      pos.x *= factor;
      gl_Position = vec4(pos, 0., 1.);
      vec2 pos2 = position;
      pos2.x /= screenRatio;
      pos2 = pos2 + 1.;
      pos2 = pos2 / 2.;
      r = position[0] == position[1] && position[0] == 0. ? 0.7 : 1.;
      vUV = pos2;
    }
    """

  bumpFragmentShaderSource: """
    precision mediump float;
    uniform sampler2D sampler;
    varying vec2 vUV;
    varying float r;

    void main(void) {
      vec2 uv = vUV * 2. - 1.;
      uv[0] *= pow(r, 1.3);
      uv[1] *= pow(r, 1.3);
      uv = (uv + 1.) / 2.;
      gl_FragColor = texture2D(sampler, uv);
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
    @_position = @GL.getAttribLocation(shaderProgram, "position")
    @_texPosition = @GL.getAttribLocation(shaderProgram, "texPosition")
    @_factor = @GL.getUniformLocation(shaderProgram, "factor")
    @_screenRatio = @GL.getUniformLocation(shaderProgram, "screenRatio")
    @_sampler = @GL.getUniformLocation(shaderProgram, "sampler")

    @GL.enableVertexAttribArray(@_position)
    @GL.enableVertexAttribArray(@_texPosition)

    return true

  initBumpShaders: ->
    vertexShader = @getShader(@GL.VERTEX_SHADER, @bumpVertexShaderSource)
    fragmentShader = @getShader(@GL.FRAGMENT_SHADER, @bumpFragmentShaderSource)
    shaderProgram = @GL.createProgram()
    @GL.attachShader(shaderProgram, vertexShader)
    @GL.attachShader(shaderProgram, fragmentShader)
    @GL.linkProgram(shaderProgram)

    @bumpShaderProgram = shaderProgram
    @_2position = @GL.getAttribLocation(shaderProgram, "position")
    @_2factor = @GL.getUniformLocation(shaderProgram, "factor")
    @_2screenRatio = @GL.getUniformLocation(shaderProgram, "screenRatio")
    @_2sampler = @GL.getUniformLocation(shaderProgram, "sampler")

    @GL.enableVertexAttribArray(@_2position)

    return true

  initHexagons: (hexagons, hexagonsHigh, widthToHeight, minR, maxR, zoomFactor) ->

    size = 2 / (hexagonsHigh / TAN30)
    fiddle =
      x: 3/10
      y: 3/10 * TAN30 / 2
    offsetX = size * (2 + fiddle.x)
    offsetY = size * (1/(2*TAN30) + fiddle.y)
    for row in [-hexagonsHigh..hexagonsHigh]
      highIndex = hexagonsHigh * widthToHeight * TAN30 / 2
      for col in [-highIndex..highIndex]
        x =
          if Math.abs(row % 2) is 1
            col * (offsetX + size)
          else
            (3 + fiddle.x) * size/2 + col * (offsetX + size)
        y = row * offsetY
        hexagons.push new Hexagon x, y, size, maxR, minR, zoomFactor

    triangleVertexData = []
    triangleFacesData = []
    for hexagon, i in hexagons
      previousVerticiesCount = triangleVertexData.length / 4
      {verticiesData, facesData} = hexagon.data(previousVerticiesCount)
      triangleVertexData.push datum for datum in verticiesData
      triangleFacesData.push datum for datum in facesData

    hexagons.triangleVertexData = triangleVertexData
    hexagons.triangleVertex = @GL.createBuffer()
    @GL.bindBuffer(@GL.ARRAY_BUFFER, hexagons.triangleVertex)
    @GL.bufferData(@GL.ARRAY_BUFFER, new Float32Array(triangleVertexData), @GL.STATIC_DRAW)

    hexagons.triangleFacesData = triangleFacesData
    hexagons.triangleFaces = @GL.createBuffer()
    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, hexagons.triangleFaces)
    @GL.bufferData(@GL.ELEMENT_ARRAY_BUFFER, new Uint16Array(triangleFacesData), @GL.STATIC_DRAW)

    return true

  initCircleSegments: (segments, segmentCount, radius) ->
    angleStep = 2 * Math.PI / segmentCount
    angle = 0
    verticies = [[0, 0]]
    for i in [0...segmentCount]
      verticies.push [
        radius * Math.sin(i * angleStep)
        radius * Math.cos(i * angleStep)
      ]
    faces = []
    for i in [1...segmentCount]
      faces.push [0, i, i+1]
    faces.push [0, segmentCount, 1]

    triangleVertexData = []
    for vertex, i in verticies
      triangleVertexData.push vertex[0]
      triangleVertexData.push vertex[1]

    triangleFacesData = []
    for face in faces
      for point in face
        triangleFacesData.push point

    segments.triangleVertexData = triangleVertexData
    segments.triangleVertex = @GL.createBuffer()
    @GL.bindBuffer(@GL.ARRAY_BUFFER, segments.triangleVertex)
    @GL.bufferData(@GL.ARRAY_BUFFER, new Float32Array(triangleVertexData), @GL.STATIC_DRAW)

    segments.triangleFacesData = triangleFacesData
    segments.triangleFaces = @GL.createBuffer()
    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, segments.triangleFaces)
    @GL.bufferData(@GL.ELEMENT_ARRAY_BUFFER, new Uint16Array(triangleFacesData), @GL.STATIC_DRAW)

    return true

  initTexture: ->
    # https://dev.opera.com/articles/webgl-post-processing/
    @texture = @GL.createTexture()
    @GL.pixelStorei(@GL.UNPACK_FLIP_Y_WEBGL, true)
    @GL.bindTexture(@GL.TEXTURE_2D, @texture)
    @GL.texParameteri(@GL.TEXTURE_2D, @GL.TEXTURE_WRAP_S, @GL.CLAMP_TO_EDGE)
    @GL.texParameteri(@GL.TEXTURE_2D, @GL.TEXTURE_WRAP_T, @GL.CLAMP_TO_EDGE)
    @GL.texParameteri(@GL.TEXTURE_2D, @GL.TEXTURE_MIN_FILTER, @GL.NEAREST)
    @GL.texParameteri(@GL.TEXTURE_2D, @GL.TEXTURE_MAG_FILTER, @GL.NEAREST)
    @GL.bindTexture(@GL.TEXTURE_2D, null)

    return

  init: ->
    try
      @initCanvas()
      @initGLContext()
      @initShaders()
      @initBumpShaders()
      fiddle = 1/150
      @bigHexagons = []
      @initHexagons(@bigHexagons, HEXAGONS_HIGH, SCREEN_RATIO, OUTER_RING_RADIUS + fiddle, Infinity, OUTER_ZOOM_FACTOR)
      @smallHexagons = []
      @initHexagons(@smallHexagons, SMALL_HEXAGONS_HIGH, 1, INNER_RING_RADIUS + fiddle, OUTER_RING_RADIUS, INNER_ZOOM_FACTOR)
      @circleSegments = []
      @initCircleSegments(@circleSegments, CIRCLE_SEGMENTS, INNER_RING_RADIUS)
      @initTexture()
      @video = document.getElementsByTagName('video')[0]
      @GL.clearColor(0.0, 0.0, 0.0, 0.0)
      return true
    catch e
      console.error e.stack
      alert("You are not compatible :(")
      return false

  draw: =>
    @GL.viewport(0.0, 0.0, @canvas.width, @canvas.height)
    @GL.clear(@GL.COLOR_BUFFER_BIT)

    @GL.useProgram(@shaderProgram)
    @GL.uniform1f(@_factor, canvas.height / canvas.width)
    @GL.uniform1f(@_screenRatio, SCREEN_RATIO)
    @GL.uniform1i(@_sampler, 0)

    @GL.bindTexture(@GL.TEXTURE_2D, @texture)
    @GL.texImage2D(@GL.TEXTURE_2D, 0, @GL.RGBA, @GL.RGBA, @GL.UNSIGNED_BYTE, @video)

    for hexagons in [@bigHexagons, @smallHexagons]
      @GL.bindBuffer(@GL.ARRAY_BUFFER, hexagons.triangleVertex)
      @GL.vertexAttribPointer(@_position, 2, @GL.FLOAT, false, 4*(2+2), 0)
      @GL.vertexAttribPointer(@_texPosition, 2, @GL.FLOAT, false, 4*(2+2), 2*4)

      @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, hexagons.triangleFaces)
      @GL.drawElements(@GL.TRIANGLES, hexagons.triangleFacesData.length, @GL.UNSIGNED_SHORT, 0)

    @GL.useProgram(@bumpShaderProgram)
    @GL.uniform1f(@_2factor, canvas.height / canvas.width)
    @GL.uniform1f(@_2screenRatio, SCREEN_RATIO)
    @GL.uniform1i(@_2sampler, 0)
    @GL.bindBuffer(@GL.ARRAY_BUFFER, @circleSegments.triangleVertex)
    @GL.vertexAttribPointer(@_2position, 2, @GL.FLOAT, false, 4*(2+0), 0)

    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, @circleSegments.triangleFaces)
    @GL.drawElements(@GL.TRIANGLES, @circleSegments.triangleFacesData.length, @GL.UNSIGNED_SHORT, 0)

    @GL.flush()

    window.requestAnimationFrame(@draw)
    return

  run: ->
    navigator.webkitGetUserMedia {video: true}, (localMediaStream) =>
      @video.src = window.URL.createObjectURL(localMediaStream)
      @draw()
    , -> alert("GUM fail.")

  start: =>
    @init() and @run()

window.addEventListener 'DOMContentLoaded', APP.start, false
