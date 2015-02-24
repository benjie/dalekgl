TAN30 = Math.tan(Math.PI/6)
OUTER_RING_RADIUS = 0.95
INNER_RING_RADIUS = 0.7
RING_WIDTH = 1/200
HEXAGONS_HIGH = 55
SCREEN_RATIO = 16/9 # 16:9 ratio
SMALL_HEXAGONS_HIGH = 75
CIRCLE_SEGMENTS = 32
OUTER_ZOOM_FACTOR = 1.11
INNER_ZOOM_FACTOR = 1.06
INNER_BUMP_R = 0.7

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
    fullyInside = true
    fullyOutside = true

    for vertex in verticies
      r = distanceFromCenter(vertex)
      isInside = (@minRadius <= r <= @maxRadius)
      vertex.push isInside
      fullyInside = fullyInside && isInside
      fullyOutside = fullyOutside && !isInside

    if fullyOutside
      verticies = []
      faces = []
    else if fullyInside
      # Noop
    else

      minR = @minRadius
      maxR = @maxRadius
      bestGuess = (vertex, otherVertex) ->
        # find the point along the line previousVertex..vertex where r hits the edge
        if minR <= distanceFromCenter(vertex) <= maxR
          # Vertex must be the OOB vertex
          [otherVertex, vertex] = [vertex, otherVertex]
        guess = vertex.slice()
        badBound = vertex.slice()
        goodBound = otherVertex.slice()

        moveToward = (v) ->
          guess[0] = (guess[0] + v[0]) / 2
          guess[1] = (guess[1] + v[1]) / 2
          return

        moveToward(goodBound)

        for i in [0..5]
          if minR <= distanceFromCenter(guess) <= maxR
            goodBound = guess.slice()
            moveToward badBound
          else
            badBound = guess.slice()
            moveToward goodBound
        return guess

      goodVerticies = []
      previousVertex = verticies[5]
      for vertex in verticies
        if previousVertex[2] isnt vertex[2]
          # One of them is outside
          goodVerticies.push bestGuess(vertex, previousVertex)
        if vertex[2]
          goodVerticies.push vertex
        previousVertex = vertex

      verticies = goodVerticies
      faces = ([1, i, i+1] for i in [2...verticies.length])


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

  colourAdjustmentDeclarations = """
    vec3 pixelColour;
    float contrast = 0.8;
    float brightness = 0.15;
    """

  colourAdjustmentCode = """
    pixelColour = vec3(raw);
    pixelColour += brightness;
    pixelColour = ((pixelColour - 0.5) * max(contrast, 0.)) + 0.5;
    pixelColour.x /= 2.;
    pixelColour.x -= 0.3;
    pixelColour.y -= 0.15;
    pixelColour.z *= 0.55;
    pixelColour.z += 0.45;

    gl_FragColor = vec4(pixelColour, 1.0);
    """

  hexagonVertexShaderSource: """
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

  hexagonFragmentShaderSource: """
    precision mediump float;
    uniform sampler2D sampler;
    varying vec2 vUV;

    #{colourAdjustmentDeclarations}

    void main(void) {
      vec4 raw = texture2D(sampler, vUV);
      #{colourAdjustmentCode}
    }
    """

  bumpVertexShaderSource: """
    attribute vec2 position;
    attribute float r;
    uniform float factor;
    uniform float screenRatio;
    varying vec2 vUV;
    varying float vR;

    void main(void) {
      vec2 pos = position;
      pos.x *= factor;
      gl_Position = vec4(pos, 0., 1.);
      vec2 pos2 = position;
      pos2.x /= screenRatio;
      pos2 = pos2 + 1.;
      pos2 = pos2 / 2.;
      vR = r;
      vUV = pos2;
    }
    """

  bumpFragmentShaderSource: """
    precision mediump float;
    uniform sampler2D sampler;
    varying vec2 vUV;
    varying float vR;

    #{colourAdjustmentDeclarations}

    void main(void) {
      vec2 uv = vUV * 2. - 1.;
      uv[0] *= pow(vR, 1.3);
      uv[1] *= pow(vR, 1.3);
      uv = (uv + 1.) / 2.;
      vec4 raw = texture2D(sampler, uv);
      #{colourAdjustmentCode}
    }
    """

  backgroundVertexShaderSource: """
    attribute vec2 position;
    uniform float factor;
    uniform float screenRatio;
    varying vec2 vUV;

    void main(void) {
      gl_Position = vec4(position, 0., 1.);
      vec2 pos2 = position;
      pos2.x /= factor;
      pos2.x /= screenRatio;
      pos2 = pos2 + 1.;
      pos2 = pos2 / 2.;
      vUV = pos2;
    }
    """

  backgroundFragmentShaderSource: """
    precision mediump float;
    uniform sampler2D sampler;
    varying vec2 vUV;
    float darkenAmount = 0.6;

    #{colourAdjustmentDeclarations}

    void main(void) {
      vec4 raw = texture2D(sampler, vUV);
      raw = vec4(vec3(raw) - darkenAmount, 1.);
      #{colourAdjustmentCode}
      gl_FragColor = vec4(pixelColour, 1.);
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

  createNamedShader: (name, attributes, uniforms) ->
    vertexShader = @getShader(@GL.VERTEX_SHADER, this["#{name}VertexShaderSource"])
    fragmentShader = @getShader(@GL.FRAGMENT_SHADER, this["#{name}FragmentShaderSource"])
    shaderProgram = @GL.createProgram()
    @GL.attachShader(shaderProgram, vertexShader)
    @GL.attachShader(shaderProgram, fragmentShader)
    @GL.linkProgram(shaderProgram)

    for varName in attributes
      shaderProgram["_#{varName}"] = @GL.getAttribLocation(shaderProgram, varName)
      @GL.enableVertexAttribArray(shaderProgram["_#{varName}"])

    for varName in uniforms
      shaderProgram["_#{varName}"] = @GL.getUniformLocation(shaderProgram, varName)

    return shaderProgram

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
      triangleVertexData.push (if i is 0 then INNER_BUMP_R else 1)

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

  initBackgroundSquare: ->
    square = {}
    triangleVertexData = [
      -1, -1
      1, -1
      1, 1
      -1, 1
    ]
    triangleFacesData = [
      0, 1, 2
      0, 2, 3
    ]

    square.triangleVertexData = triangleVertexData
    square.triangleVertex = @GL.createBuffer()
    @GL.bindBuffer(@GL.ARRAY_BUFFER, square.triangleVertex)
    @GL.bufferData(@GL.ARRAY_BUFFER, new Float32Array(triangleVertexData), @GL.STATIC_DRAW)

    square.triangleFacesData = triangleFacesData
    square.triangleFaces = @GL.createBuffer()
    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, square.triangleFaces)
    @GL.bufferData(@GL.ELEMENT_ARRAY_BUFFER, new Uint16Array(triangleFacesData), @GL.STATIC_DRAW)

    @backgroundSquare = square
    return

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
      @shaderProgram = @createNamedShader('hexagon', ['position', 'texPosition'], ['factor', 'screenRatio', 'sampler'])
      @bumpShaderProgram = @createNamedShader('bump', ['position', 'r'], ['factor', 'screenRatio', 'sampler'])
      @backgroundShaderProgram = @createNamedShader('background', ['position'], ['factor', 'screenRatio', 'sampler'])
      @bigHexagons = []
      @initHexagons(@bigHexagons, HEXAGONS_HIGH, SCREEN_RATIO, OUTER_RING_RADIUS + RING_WIDTH, Infinity, OUTER_ZOOM_FACTOR)
      @smallHexagons = []
      @initHexagons(@smallHexagons, SMALL_HEXAGONS_HIGH, 1, INNER_RING_RADIUS + RING_WIDTH, OUTER_RING_RADIUS, INNER_ZOOM_FACTOR)
      @circleSegments = []
      @initCircleSegments(@circleSegments, CIRCLE_SEGMENTS, INNER_RING_RADIUS)
      @initBackgroundSquare()
      @initTexture()
      @image = document.getElementsByTagName('img')[0]
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

    @GL.useProgram(@backgroundShaderProgram)
    @GL.uniform1f(@backgroundShaderProgram._factor, canvas.height / canvas.width)
    @GL.uniform1f(@backgroundShaderProgram._screenRatio, SCREEN_RATIO)
    @GL.uniform1i(@backgroundShaderProgram._sampler, 0)

    @GL.bindBuffer(@GL.ARRAY_BUFFER, @backgroundSquare.triangleVertex)
    @GL.vertexAttribPointer(@backgroundShaderProgram._position, 2, @GL.FLOAT, false, 4*(2+0), 0)

    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, @backgroundSquare.triangleFaces)
    @GL.drawElements(@GL.TRIANGLES, @backgroundSquare.triangleFacesData.length, @GL.UNSIGNED_SHORT, 0)


    @GL.useProgram(@shaderProgram)
    @GL.uniform1f(@shaderProgram._factor, canvas.height / canvas.width)
    @GL.uniform1f(@shaderProgram._screenRatio, SCREEN_RATIO)
    @GL.uniform1i(@shaderProgram._sampler, 0)

    @GL.bindTexture(@GL.TEXTURE_2D, @texture)
    textureSource =
      if @video.loaded
        @video
      else
        @image
    @GL.texImage2D(@GL.TEXTURE_2D, 0, @GL.RGBA, @GL.RGBA, @GL.UNSIGNED_BYTE, textureSource)

    for hexagons in [@bigHexagons, @smallHexagons]
      @GL.bindBuffer(@GL.ARRAY_BUFFER, hexagons.triangleVertex)
      @GL.vertexAttribPointer(@shaderProgram._position, 2, @GL.FLOAT, false, 4*(2+2), 0)
      @GL.vertexAttribPointer(@shaderProgram._texPosition, 2, @GL.FLOAT, false, 4*(2+2), 2*4)

      @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, hexagons.triangleFaces)
      @GL.drawElements(@GL.TRIANGLES, hexagons.triangleFacesData.length, @GL.UNSIGNED_SHORT, 0)

    @GL.useProgram(@bumpShaderProgram)
    @GL.uniform1f(@bumpShaderProgram._factor, canvas.height / canvas.width)
    @GL.uniform1f(@bumpShaderProgram._screenRatio, SCREEN_RATIO)
    @GL.uniform1i(@bumpShaderProgram._sampler, 0)
    @GL.bindBuffer(@GL.ARRAY_BUFFER, @circleSegments.triangleVertex)
    @GL.vertexAttribPointer(@bumpShaderProgram._position, 2, @GL.FLOAT, false, 4*(2+1), 0)
    @GL.vertexAttribPointer(@bumpShaderProgram._r, 1, @GL.FLOAT, false, 4*(2+1), 4*2)

    @GL.bindBuffer(@GL.ELEMENT_ARRAY_BUFFER, @circleSegments.triangleFaces)
    @GL.drawElements(@GL.TRIANGLES, @circleSegments.triangleFacesData.length, @GL.UNSIGNED_SHORT, 0)

    @GL.flush()

    window.requestAnimationFrame(@draw)
    return

  run: ->
    @draw()
    navigator.webkitGetUserMedia {video: true}, (localMediaStream) =>
      @video.src = window.URL.createObjectURL(localMediaStream)
      @video.loaded = true
    , -> alert("GUM fail.")

  start: =>
    @init() and @run()

window.addEventListener 'DOMContentLoaded', APP.start, false
